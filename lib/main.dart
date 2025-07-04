import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const PDFViewerApp());
}

class PDFViewerApp extends StatelessWidget {
  const PDFViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Viewer (Web + Android)',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const PDFHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PDFHomePage extends StatefulWidget {
  const PDFHomePage({super.key});

  @override
  State<PDFHomePage> createState() => _PDFHomePageState();
}

class _PDFHomePageState extends State<PDFHomePage> {
  Uint8List? _pdfBytes;

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pdfBytes = result.files.single.bytes!;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load PDF')),
        );
      }
    } catch (e) {
      debugPrint('PDF load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Viewer')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickPDF,
            child: const Text('Pick a PDF File'),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _pdfBytes == null
                ? const Center(child: Text('No PDF selected'))
                : SfPdfViewer.memory(_pdfBytes!),
          ),
        ],
      ),
    );
  }
}
