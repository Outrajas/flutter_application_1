import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadModelAndTokenizer();
  runApp(const CleanPDFApp());
}

// === ML Globals ===
late Interpreter _interpreter;
late Map<String, int> _wordIndex;
const int _maxLen = 100;

// === Load model and tokenizer from assets ===
Future<void> _loadModelAndTokenizer() async {
  // Load model
  _interpreter = await Interpreter.fromAsset('assets/pdf_cleaner_model.tflite');
  
  // Load tokenizer
  final tokenizerJson = await rootBundle.loadString('assets/tokenizer.json');
  final tokenizerMap = jsonDecode(tokenizerJson);
  
  // Extract word_index from tokenizer config
  if (tokenizerMap['config'] == null || 
      tokenizerMap['config']['word_index'] == null) {
    throw Exception("❌ tokenizer.json missing 'word_index' in config.");
  }
  
  final wordIndexMap = Map<String, dynamic>.from(tokenizerMap['config']['word_index']);
  _wordIndex = wordIndexMap.map((key, value) => MapEntry(key, value as int));
}

// === Predict score for a line ===
Future<double> predictLine(String line) async {
  // Tokenize and preprocess the line
  final input = _tokenizeLine(line);
  
  // Create output tensor
  final output = List.filled(1, 0.0).reshape([1, 1]);
  
  // Run inference
  _interpreter.run([input], [output]);
  
  return output[0][0];
}

// === Tokenize a line using word_index map ===
List<List<double>> _tokenizeLine(String line) {
  // 1. Lowercase and split into words
  final words = line.toLowerCase().split(RegExp(r'\s+'));
  
  // 2. Convert words to token IDs
  List<int> tokenIds = [];
  for (final word in words) {
    final id = _wordIndex[word] ?? 0;  // Use 0 for OOV
    if (id != 0) {  // Only add non-zero tokens
      tokenIds.add(id);
    }
  }
  
  // 3. Apply truncation and padding
  List<int> processed = [];
  
  // Truncate from end if too long
  if (tokenIds.length > _maxLen) {
    processed = tokenIds.sublist(tokenIds.length - _maxLen);
  } 
  // Pad at beginning if too short
  else if (tokenIds.length < _maxLen) {
    processed = List.filled(_maxLen - tokenIds.length, 0) + tokenIds;
  } 
  // Exact length
  else {
    processed = tokenIds;
  }
  
  // 4. Convert to 2D tensor [1, maxLen] with float values
  return [processed.map((id) => id.toDouble()).toList()];
}

class CleanPDFApp extends StatelessWidget {
  const CleanPDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '📊 Clean PDF (Model Running)',
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const PDFViewerScreen(),
    );
  }
}

class PDFViewerScreen extends StatefulWidget {
  const PDFViewerScreen({super.key});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  List<String> cleanedLines = [];
  List<String> removedLines = [];
  bool isLoading = false;
  int processedCount = 0;
  int totalLines = 0;

  Future<void> _pickPDF() async {
    setState(() {
      isLoading = true;
      cleanedLines.clear();
      removedLines.clear();
      processedCount = 0;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      Uint8List bytes = result.files.single.bytes!;
      final document = PdfDocument(inputBytes: bytes);
      final raw = PdfTextExtractor(document).extractText();
      document.dispose();

      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      totalLines = lines.length;

      for (String line in lines) {
        try {
          double score = await predictLine(line);
          String labeledLine = "[${score.toStringAsFixed(2)}] $line";

          if (score > 0.5) {
            cleanedLines.add(labeledLine);
          } else {
            removedLines.add(labeledLine);
          }

          setState(() => processedCount++);
        } catch (e) {
          debugPrint("⚠️ Error: $e");
        }
      }

      setState(() => isLoading = false);
    } else {
      setState(() => isLoading = false);
    }
  }

  void _clearPDF() {
    setState(() {
      cleanedLines.clear();
      removedLines.clear();
      processedCount = 0;
      totalLines = 0;
    });
  }

  Widget _buildTextList(List<String> lines, String label) {
    if (lines.isEmpty) {
      return Center(child: Text("No $label text found."));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: SelectableText(
          lines.join('\n\n'),
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("📊 Clean PDF (Model Running)"),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cleaned'),
              Tab(text: 'Removed'),
            ],
          ),
          actions: [
            if (totalLines > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '$processedCount/$totalLines',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(Icons.clear, color: isDark ? Colors.white : Colors.black),
              tooltip: "Clear",
              onPressed: _clearPDF,
            ),
            IconButton(
              icon: Icon(Icons.file_open, color: isDark ? Colors.white : Colors.black),
              tooltip: "Open PDF",
              onPressed: _pickPDF,
            ),
          ],
        ),
        floatingActionButton: isLoading
            ? null
            : FloatingActionButton(
                onPressed: _pickPDF,
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                child: const Icon(Icons.file_open),
              ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      "Processing $processedCount/$totalLines lines",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  _buildTextList(cleanedLines, 'cleaned'),
                  _buildTextList(removedLines, 'removed'),
                ],
              ),
      ),
    );
  }
}