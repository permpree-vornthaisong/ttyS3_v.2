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
      _status = 'Printing image from file first...';
    });

    try {
      print('🔍 DEBUG: Starting print image from file...');

      // 🎯 1. โหลดรูปจากไฟล์เป็น bytes ก่อน
      setState(() => _status = 'Loading image from assets...');

      final ByteData data = await rootBundle.load('assets/LOGOq.jpg');
      final Uint8List imageBytes = data.buffer.asUint8List();

      print('✅ Image loaded, size: ${imageBytes.length} bytes');

      // 2. ส่ง bytes ไปพิมพ์ (ไม่ใช่ path)
      setState(() => _status = 'Sending image bytes to printer...');

      bool imageSuccess = await logic.printImageBytes(
        imageBytes: imageBytes,
        portPath: '/dev/ttyS3',
        method: 'printImageFromBytes',
      );

      if (!imageSuccess) {
        throw Exception('Failed to print image from file');
      }

      print('✅ Image from file printed successfully');
      setState(() => _status = 'Image printed! Now creating PDF...');

      // เดี๋ยวสักครู่ก่อนทำต่อ
      await Future.delayed(Duration(seconds: 2));

      // 🎯 2. จากนั้นค่อยสร้าง PDF และพิมพ์ผ่าน Java
      print('🔍 DEBUG: Starting PDF creation...');
      setState(() => _status = 'Creating PDF...');

      final Uint8List? pdfBytes = await logic.createReceiptPDF(jsonData);

      if (pdfBytes == null) {
        throw Exception('Failed to create PDF');
      }

      print('🔍 DEBUG: PDF created, size: ${pdfBytes.length} bytes');
      setState(() => _status = 'Converting PDF to image in Java...');

      // 3. ส่ง PDF ไป Java แปลงเป็นรูปและพิมพ์
      final result = await _channel.invokeMethod('printPdfAsImage', {
        'pdfData': pdfBytes,
        'portPath': '/dev/ttyS3',
        'dpi': 150,
      });

      print('✅ PDF print result: $result');
      setState(
          () => _status = 'Both completed! Image from file + PDF via Java');
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
