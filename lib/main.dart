import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadTokenizerAndModel();
  runApp(const PDFCleanerApp());
}

// === TFLite and Tokenizer ===
late Interpreter _interpreter;
late Map<String, int> _wordIndex;
const int _maxLen = 100;
late int _oovIndex;

Future<void> _loadTokenizerAndModel() async {
  _interpreter = await Interpreter.fromAsset('assets/pdf_cleaner_model.tflite');
  final tokenizerJson = await rootBundle.loadString('assets/tokenizer.json');
  final parsedJson = jsonDecode(tokenizerJson);
  final wordIndexMap = Map<String, dynamic>.from(parsedJson['word_index']);
  _wordIndex = wordIndexMap.map((k, v) => MapEntry(k, (v as num).toInt()));
  _oovIndex = _wordIndex["<OOV>"] ?? 1;
  print("✅ Tokenizer Loaded: ${_wordIndex.length} words");
}

String cleanText(String text) {
  return text.toLowerCase().replaceAll(RegExp(r"[^\w\s.,;?!]"), "");
}

List<double> _tokenizeLine(String line) {
  final cleaned = cleanText(line);
  final words = cleaned.split(RegExp(r'\s+'));
  final tokens = words.map((w) => _wordIndex[w] ?? _oovIndex).toList();
  final padded = List<double>.filled(_maxLen, 0.0);
  final start = tokens.length > _maxLen ? tokens.length - _maxLen : 0;
  final finalTokens = tokens.sublist(start);
  for (int i = 0; i < finalTokens.length; i++) {
    padded[i] = finalTokens[i].toDouble();
  }
  return padded;
}

Future<double> predictLine(String line) async {
  final input = [_tokenizeLine(line)];
  final output = List.filled(1 * 1, 0.0).reshape([1, 1]);
  _interpreter.run(input, output);
  return output[0][0];
}

// === UI Starts ===

class PDFCleanerApp extends StatelessWidget {
  const PDFCleanerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '📊 PDF Cleaner',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const CleanerHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CleanerHomeScreen extends StatefulWidget {
  const CleanerHomeScreen({super.key});
  @override
  State<CleanerHomeScreen> createState() => _CleanerHomeScreenState();
}

class _CleanerHomeScreenState extends State<CleanerHomeScreen> {
  List<String> uncleaned = [], cleaned = [], removed = [];
  bool isLoading = false, isProcessing = false;
  int processed = 0, total = 0;

  final TextEditingController _debugController = TextEditingController(text: "Example sentence for debug.");
  String cleanedDebug = "";
  List<double> tokenDebug = [];

  Future<void> pickPDF() async {
    setState(() {
      uncleaned.clear(); cleaned.clear(); removed.clear();
      processed = 0; total = 0; isLoading = true; isProcessing = true;
    });

    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) {
      setState(() => isLoading = false);
      return;
    }

    final doc = PdfDocument(inputBytes: result.files.single.bytes!);
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();

    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    total = lines.length;
    setState(() => uncleaned.addAll(lines));

    for (final line in lines) {
      if (!isProcessing) break;
      final score = await predictLine(line);
      setState(() {
        if (score > 0.5) cleaned.add(line); else removed.add(line);
        processed++;
      });
      await Future.delayed(const Duration(milliseconds: 1));
    }

    setState(() { isLoading = false; isProcessing = false; });
  }

  void debugTokenizer(String line) {
    final cleaned = cleanText(line);
    final tokens = _tokenizeLine(line);
    setState(() {
      cleanedDebug = cleaned;
      tokenDebug = tokens;
    });
    print("✅ Cleaned: $cleaned");
    print("✅ Tokens: $tokens");
  }

  Widget listSection(String title, List<String> lines) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text("$title (${lines.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      Expanded(
        child: lines.isEmpty
            ? Center(child: Text("No $title lines found"))
            : ListView.builder(
                itemCount: lines.length,
                itemBuilder: (c, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(lines[i], style: const TextStyle(fontSize: 16)),
                  )),
                ),
              ),
      ),
    ]);
  }

  Widget debugSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Tokenizer Debug", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _debugController,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Enter line"),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => debugTokenizer(_debugController.text),
          child: const Text("Run Tokenizer"),
        ),
        const SizedBox(height: 10),
        if (cleanedDebug.isNotEmpty) Text("✅ Cleaned Text:\n$cleanedDebug"),
        if (tokenDebug.isNotEmpty) Text("✅ Tokens:\n${tokenDebug.where((e) => e != 0).toList()}"),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("📊 PDF Cleaner"),
          bottom: const TabBar(tabs: [
            Tab(text: "Uncleaned"),
            Tab(text: "Cleaned"),
            Tab(text: "Removed"),
            Tab(text: "Debug"),
          ]),
          actions: [
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Chip(label: Text("$processed/$total"))),
              ),
            IconButton(
              icon: Icon(isProcessing ? Icons.cancel : Icons.upload_file),
              onPressed: isLoading
                  ? null
                  : () {
                      if (isProcessing) setState(() => isProcessing = false);
                      else pickPDF();
                    },
            )
          ],
        ),
        body: TabBarView(children: [
          listSection("Uncleaned", uncleaned),
          listSection("Cleaned", cleaned),
          listSection("Removed", removed),
          debugSection(),
        ]),
      ),
    );
  }
}
