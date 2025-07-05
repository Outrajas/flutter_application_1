// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:pdfx/pdfx.dart';

// void main() {
//   runApp(const PDFViewerApp());
// }

// class PDFViewerApp extends StatelessWidget {
//   const PDFViewerApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'PDF Viewer',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         scaffoldBackgroundColor: Colors.grey[100],
//         appBarTheme: const AppBarTheme(
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black,
//           elevation: 1,
//         ),
//       ),
//       debugShowCheckedModeBanner: false,
//       home: const PDFViewerScreen(),
//     );
//   }
// }

// class PDFViewerScreen extends StatefulWidget {
//   const PDFViewerScreen({super.key});

//   @override
//   State<PDFViewerScreen> createState() => _PDFViewerScreenState();
// }

// class _PDFViewerScreenState extends State<PDFViewerScreen> {
//   PdfController? _pdfController;
//   String? _fileName;
//   String? _errorMessage;
//   bool _isLoading = false;
//   int _currentPage = 1;
//   int _totalPages = 0;

//   Future<void> _pickAndDisplayPDF() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//       _pdfController?.dispose();
//       _pdfController = null;
//       _fileName = null;
//       _currentPage = 1;
//       _totalPages = 0;
//     });

//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['pdf'],
//         withData: true, // Important for getting file bytes
//       );

//       if (result == null || result.files.isEmpty) {
//         setState(() {
//           _isLoading = false;
//           _errorMessage = 'No file selected';
//         });
//         return;
//       }

//       final file = result.files.first;
//       setState(() => _fileName = file.name);

//       if (file.bytes == null) {
//         throw Exception('Failed to load PDF content');
//       }

//       final pdfDoc = await PdfDocument.openData(file.bytes!);
//       setState(() {
//         _pdfController = PdfController(
//           document: Future.value(pdfDoc),
//           initialPage: 1,
//         );
//         _totalPages = pdfDoc.pagesCount;
//       });

//       setState(() => _isLoading = false);
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
//       });
//       print('PDF error: $e');
//     }
//   }

//   @override
//   void dispose() {
//     _pdfController?.dispose();
//     super.dispose();
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       color: Colors.white,
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 if (_fileName != null)
//                   Text(
//                     _fileName!,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 if (_totalPages > 0)
//                   Text(
//                     'Page $_currentPage of $_totalPages',
//                     style: TextStyle(
//                       color: Colors.grey[600],
//                       fontSize: 14,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _pickAndDisplayPDF,
//             tooltip: 'Select another PDF',
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPaginationControls() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       color: Colors.white,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: _currentPage > 1
//                 ? () => _pdfController?.previousPage(
//                       curve: Curves.ease,
//                       duration: const Duration(milliseconds: 300),
//                     )
//                 : null,
//           ),
//           const SizedBox(width: 20),
//           IconButton(
//             icon: const Icon(Icons.arrow_forward),
//             onPressed: _currentPage < _totalPages
//                 ? () => _pdfController?.nextPage(
//                       curve: Curves.ease,
//                       duration: const Duration(milliseconds: 300),
//                     )
//                 : null,
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('PDF Viewer'),
//         centerTitle: true,
//       ),
//       body: Column(
//         children: [
//           if (_pdfController != null) _buildHeader(),
//           if (_errorMessage != null)
//             Container(
//               padding: const EdgeInsets.all(16),
//               color: Colors.red[50],
//               child: Row(
//                 children: [
//                   const Icon(Icons.error, color: Colors.red),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Text(
//                       _errorMessage!,
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           if (_isLoading)
//             const Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 20),
//                     Text('Loading PDF...'),
//                   ],
//                 ),
//               ),
//             )
//           else if (_pdfController != null)
//             Expanded(
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: PdfView(
//                       controller: _pdfController!,
//                       scrollDirection: Axis.vertical,
//                       onPageChanged: (page) {
//                         setState(() => _currentPage = page);
//                       },
//                       renderer: (PdfPage page) => page.render(
//                         width: page.width * 2,
//                         height: page.height * 2,
//                       ),
//                     ),
//                   ),
//                   _buildPaginationControls(),
//                 ],
//               ),
//             )
//           else
//             Expanded(
//               child: Center(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       Icons.picture_as_pdf,
//                       size: 80,
//                       color: Colors.grey[400],
//                     ),
//                     const SizedBox(height: 20),
//                     const Text(
//                       'No PDF Selected',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       'Select a PDF file to view its content',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//                     ElevatedButton(
//                       onPressed: _pickAndDisplayPDF,
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 32, vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                       ),
//                       child: const Text(
//                         'SELECT PDF FILE',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _pickAndDisplayPDF,
//         backgroundColor: Colors.blue,
//         child: const Icon(Icons.file_open, color: Colors.white),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  runApp(MaterialApp(home: PdfTextExtractorPage()));
}

class PdfTextExtractorPage extends StatefulWidget {
  @override
  _PdfTextExtractorPageState createState() => _PdfTextExtractorPageState();
}

class _PdfTextExtractorPageState extends State<PdfTextExtractorPage> {
  String? extractedText;
  bool loading = false;

  Future<void> pickPdfAndExtractText() async {
    setState(() {
      loading = true;
      extractedText = null;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final bytes = File(path).readAsBytesSync();

      PdfDocument document = PdfDocument(inputBytes: bytes);
      PdfTextExtractor extractor = PdfTextExtractor(document);
      String text = extractor.extractText();
      document.dispose();

      setState(() {
        extractedText = text;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF Text Extractor')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? Center(child: CircularProgressIndicator())
            : extractedText != null
                ? SingleChildScrollView(child: Text(extractedText!))
                : Center(child: Text('Pick a PDF to extract text')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickPdfAndExtractText,
        tooltip: 'Pick PDF',
        child: Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
