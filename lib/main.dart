import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _loadModelAndTokenizer();
    runApp(const CleanPDFApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text(
                  "Critical Error",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  "Failed to load model resources:",
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text("Retry"),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => exit(0),
                  child: const Text("Exit App"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === ML Globals ===
late Interpreter _interpreter;
late Map<String, int> _wordIndex;
const int _maxLen = 100;
late int _oovIndex;
late List<int> _inputShape;

// === Load model and tokenizer from assets ===
Future<void> _loadModelAndTokenizer() async {
  try {
    print("🟢 Loading TensorFlow Lite model...");
    _interpreter = await Interpreter.fromAsset(
      'assets/pdf_cleaner_model.tflite',
      options: InterpreterOptions()..threads = 6,
    );

    // Get model input details
    final inputDetails = _interpreter.getInputTensors();
    print("🔧 Model input details:");
    for (var detail in inputDetails) {
      print("- Shape: ${detail.shape}, Type: ${detail.type}, Name: ${detail.name}");
      _inputShape = List<int>.from(detail.shape);
    }

    print("🔧 Expected input shape: $_inputShape");

    print("🟢 Loading tokenizer...");
    final tokenizerJson = await rootBundle.loadString('assets/tokenizer.json');
    final parsedJson = jsonDecode(tokenizerJson);

    // Handle different JSON structures
    Map<String, dynamic> wordIndexMap;

    if (parsedJson is Map<String, dynamic> && parsedJson.containsKey('word_index')) {
      wordIndexMap = Map<String, dynamic>.from(parsedJson['word_index']);
    } else if (parsedJson is Map<String, dynamic>) {
      wordIndexMap = parsedJson;
    } else {
      throw Exception("❌ Invalid tokenizer format: ${parsedJson.runtimeType}");
    }

    print("🔄 Converting tokenizer values...");
    _wordIndex = {};
    wordIndexMap.forEach((key, value) {
      if (value is int) {
        _wordIndex[key] = value;
      } else if (value is String) {
        _wordIndex[key] = int.tryParse(value) ?? 1;
      } else if (value is double) {
        _wordIndex[key] = value.toInt();
      } else {
        print("⚠️ Unexpected token type for '$key': ${value.runtimeType}");
        _wordIndex[key] = 1;
      }
    });

    _oovIndex = _wordIndex["<OOV>"] ?? 1;

    print("✅ Loaded ${_wordIndex.length} vocabulary items");
    print("✅ Model and tokenizer loaded successfully");
  } catch (e) {
    print("🔴 Critical error in _loadModelAndTokenizer: $e");
    rethrow;
  }
}


// === Clean text for consistent tokenization ===
String cleanText(String text) {
  text = text.toLowerCase();
  text = text.replaceAll(RegExp(r"[^\w\s.,;?!]"), "");
  return text;
}

// === Tokenize a line using word_index map ===
List<double> _tokenizeLine(String line) {
  line = cleanText(line);
  final words = line.split(RegExp(r'\s+'));
  
  List<int> tokenIds = [];
  for (final word in words) {
    if (word.isEmpty) continue;
    final id = _wordIndex[word] ?? _oovIndex;
    tokenIds.add(id);
  }
  
  final processed = List<double>.filled(_maxLen, 0.0);
  int length = tokenIds.length;
  
  if (length > _maxLen) {
    tokenIds = tokenIds.sublist(length - _maxLen);
    length = _maxLen;
  }
  
  for (int i = 0; i < length; i++) {
    processed[i] = tokenIds[i].toDouble();
  }
  
  return processed;
}

// === Predict score for a line ===
Future<double> predictLine(String line) async {
  try {
    final tokenized = _tokenizeLine(line);

    // Match the model's expected input shape
    late var inputArray;
    if (_inputShape.length == 2) {
      // [1, 100]
      inputArray = [tokenized];
    } else if (_inputShape.length == 3) {
      // [1, 100, 1]
      inputArray = [tokenized.map((x) => [x]).toList()];
    } else if (_inputShape.length == 4) {
      // [1, 1, 100, 1]
      inputArray = [[[tokenized.map((x) => [x]).toList()]]];
    } else {
      throw Exception("❌ Unsupported input shape: $_inputShape");
    }

    final outputArray = List.generate(1, (_) => List.filled(1, 0.0));

    _interpreter.run(inputArray, outputArray);

    return outputArray[0][0];
  } catch (e) {
    print("🔴 Error in predictLine: $e");
    return 0.5;
  }
}


class CleanPDFApp extends StatelessWidget {
  const CleanPDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '📊 Clean PDF',
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
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
  List<String> uncleanedLines = [];
  List<String> cleanedLines = [];
  List<String> removedLines = [];
  bool isLoading = false;
  int processedCount = 0;
  int totalLines = 0;
  bool isProcessing = false;
  String? errorMessage;

  Future<void> _pickPDF() async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
      isProcessing = true;
      errorMessage = null;
      uncleanedLines.clear();
      cleanedLines.clear();
      removedLines.clear();
      processedCount = 0;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => isLoading = false);
        return;
      }

      Uint8List bytes = result.files.single.bytes!;
      final document = PdfDocument(inputBytes: bytes);
      final raw = PdfTextExtractor(document).extractText();
      document.dispose();

      final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      totalLines = lines.length;
      
      // Process lines in batches for better performance
      for (int i = 0; i < lines.length; i++) {
        if (!isProcessing) break;
        
        final line = lines[i];
        try {
          setState(() => uncleanedLines.add(line));
          
          double score = await predictLine(line);
          String labeledLine = "[${score.toStringAsFixed(2)}] $line";

          setState(() {
            if (score > 0.5) {
              cleanedLines.add(labeledLine);
            } else {
              removedLines.add(labeledLine);
            }
            processedCount++;
          });
          
          await Future.delayed(const Duration(milliseconds: 1));
        } catch (e) {
          debugPrint("⚠️ Error processing line: $e");
          setState(() => processedCount++);
        }
      }
    } catch (e) {
      setState(() => errorMessage = "Error processing PDF: ${e.toString()}");
      print("🔴 PDF processing error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _clearPDF() {
    setState(() {
      uncleanedLines.clear();
      cleanedLines.clear();
      removedLines.clear();
      processedCount = 0;
      totalLines = 0;
      errorMessage = null;
    });
  }
  
  void _cancelProcessing() {
    setState(() {
      isProcessing = false;
      isLoading = false;
      errorMessage = "Processing cancelled";
    });
  }

  Widget _buildTextList(List<String> lines, String title, bool showScores) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "$title (${lines.length} lines)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        if (lines.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                "No $title text found",
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        showScores ? line : line.replaceAll(RegExp(r'^\[\d+\.\d+\]\s*'), ''),
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Clean PDF"),
        actions: [
          if (totalLines > 0) ...[
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  label: Text(
                    '$processedCount/$totalLines',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                ),
              ),
            ),
          ],
          IconButton(
            icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
            tooltip: "Clear",
            onPressed: _clearPDF,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading ? null : _pickPDF,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.file_open),
      ),
      body: errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    errorMessage!,
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _clearPDF,
                    child: const Text("Clear Error"),
                  ),
                ],
              ),
            )
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Material(
                    child: TabBar(
                      tabs: const [
                        Tab(icon: Icon(Icons.description), text: 'Uncleaned'),
                        Tab(icon: Icon(Icons.cleaning_services), text: 'Cleaned'),
                        Tab(icon: Icon(Icons.delete), text: 'Removed'),
                      ],
                      indicatorColor: theme.colorScheme.secondary,
                      labelColor: theme.colorScheme.secondary,
                      unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        TabBarView(
                          children: [
                            _buildTextList(uncleanedLines, 'Uncleaned', false),
                            _buildTextList(cleanedLines, 'Cleaned', true),
                            _buildTextList(removedLines, 'Removed', true),
                          ],
                        ),
                        
                        if (isLoading)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.7),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 20),
                                    Text(
                                      "Processing PDF...",
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: theme.colorScheme.onBackground,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "$processedCount/$totalLines lines processed",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: theme.colorScheme.onBackground,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _cancelProcessing,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.error,
                                      ),
                                      child: const Text("Cancel Processing"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}