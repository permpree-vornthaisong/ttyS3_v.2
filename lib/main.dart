import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unit_test_java_tty/logic_imageprint.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _channel = const MethodChannel('com.example.unittest/printer');
  bool _isPrinting = false;
  String _status = 'Ready';
  final logic = ImagePrintLogic();

  final jsonData = {
    'title': 'ใบเสร็จรับเงิน', // ✅ เปลี่ยนเป็นไทย
    'date': '04/06/2025',
    'items': [
      {'name': 'กาแฟ', 'price': 50.0},
      {'name': 'ขนม', 'price': 25.0},
    ]
  };

  Future<void> _printSingleImage() async {
    setState(() {
      _isPrinting = true;
      _status = 'Creating single image...';
    });

    try {
      print('🔍 DEBUG: Starting single image creation...');

      // 1. สร้างรูปภาพเดียว
      final Uint8List? imageBytes = await logic.createReceiptImage(jsonData);

      if (imageBytes == null) {
        throw Exception('Failed to create image');
      }

      print('🔍 DEBUG: Single image created, size: ${imageBytes.length} bytes');

      setState(() => _status = 'Sending to printer...');

      // 2. ส่งไปพิมพ์
      final result = await _channel.invokeMethod('printImageFromBytes', {
        'imageData': imageBytes,
        'portPath': '/dev/ttyS3',
      });

      setState(() => _status = 'Print result: $result');
    } catch (e) {
      print('🔴 ERROR: $e');
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  // ✅ แก้ไข method นี้ - ลบ paperWidth parameter
  Future<void> _printWithPDFConversion() async {
    setState(() {
      _isPrinting = true;
      _status = 'Creating PDF...';
    });

    try {
      print('🔍 DEBUG: Starting PDF creation...');

      // 1. สร้าง PDF ใน Dart
      final Uint8List? pdfBytes = await logic.createReceiptPDF(jsonData);

      if (pdfBytes == null) {
        throw Exception('Failed to create PDF');
      }

      print('🔍 DEBUG: PDF created, size: ${pdfBytes.length} bytes');

      setState(() => _status = 'Converting PDF to image in Java...');

      // 2. ส่ง PDF ไป Java แปลงเป็นรูปและพิมพ์ (ไม่ส่ง paperWidth)
      final result = await _channel.invokeMethod('printPdfAsImage', {
        'pdfData': pdfBytes, // ✅ ส่ง PDF bytes
        'portPath': '/dev/ttyS3',
        'dpi': 150, // ✅ กำหนด DPI
        // ❌ ลบ 'paperWidth' ออก - ให้ Java ใช้ขนาดจริงของ PDF
      });

      setState(() => _status = 'Print result: $result');
    } catch (e) {
      print('🔴 ERROR: $e');
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Options'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status
            Text(
              _status,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // ✅ เพิ่มปุ่มใหม่
            ElevatedButton(
              onPressed: _isPrinting ? null : _printWithPDFConversion,
              child: _isPrinting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Print PDF via Java'),
            ),

            const SizedBox(height: 20),

            // ปุ่มเดิม (Flutter conversion)
            ElevatedButton(
              onPressed: _isPrinting ? null : _printSingleImage,
              child: _isPrinting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Print via Flutter'),
            ),
          ],
        ),
      ),
    );
  }
}
