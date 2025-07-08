import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  runApp(const CleanPDFApp());
}

class CleanPDFApp extends StatelessWidget {
  const CleanPDFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean PDF Reader',
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
  String? extractedText;
  bool isLoading = false;

  Future<void> _pickPDF() async {
    setState(() {
      isLoading = true;
      extractedText = null;
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

      final clean = _cleanText(raw);
      setState(() {
        extractedText = clean;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  String _cleanText(String input) {
    final lines = input.split('\n');
    final skipWords = ['chapter', 'contents', 'by', 'copyright', 'index'];
    return lines
        .where((line) {
          final l = line.trim().toLowerCase();
          return l.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(l) &&
              skipWords.every((skip) => !l.contains(skip));
        })
        .join('\n');
  }

  void _clearPDF() {
    setState(() {
      extractedText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Clean PDF Reader"),
        actions: [
          if (extractedText != null)
            TopBarButtons(
              onBack: _clearPDF,
              onPick: _pickPDF,
              isDark: isDark,
            )
        ],
      ),
      floatingActionButton: extractedText == null
          ? ButtonBarFloating(
              isDark: isDark,
              onPressed: _pickPDF,
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : extractedText != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      extractedText!,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                )
              : Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_open),
                    label: const Text("Select a PDF"),
                    onPressed: _pickPDF,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ),
    );
  }
}

class TopBarButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onPick;
  final bool isDark;

  const TopBarButtons({
    super.key,
    required this.onBack,
    required this.onPick,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDark ? Colors.white : Colors.black;
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: onBack,
        ),
        IconButton(
          icon: Icon(Icons.file_open, color: iconColor),
          onPressed: onPick,
        ),
      ],
    );
  }
}

class ButtonBarFloating extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isDark;

  const ButtonBarFloating({
    super.key,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: isDark ? Colors.white : Colors.black,
      foregroundColor: isDark ? Colors.black : Colors.white,
      child: const Icon(Icons.file_open),
    );
  }
}
