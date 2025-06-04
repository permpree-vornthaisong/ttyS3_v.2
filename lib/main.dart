import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

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

  // Printer configuration
  static const String PORT_PATH = '/dev/ttyS3';
  static const int PRINTER_WIDTH = 500; // 50mm printer in dots

  // ESC/POS Commands
  static const List<int> ESC_INIT = [0x1B, 0x40];
  static const List<int> ESC_ALIGN_CENTER = [0x1B, 0x61, 0x01];
  static const List<int> ESC_ALIGN_LEFT = [0x1B, 0x61, 0x00];
  static const List<int> ESC_FEED_3 = [0x1B, 0x64, 0x03];
  static const List<int> SWAP_INT_COLOR = [1, 0];

  Future<void> _printLargeImage() async {
    setState(() {
      _isPrinting = true;
      _status = 'Loading image from Dart...';
    });

    try {
      // 1. Load image data ใน Dart
      final ByteData data = await rootBundle.load('assets/page_1x.png');
      final Uint8List imageBytes = data.buffer.asUint8List();

      setState(() => _status = 'Sending image data to Java...');

      // 2. ส่งข้อมูลรูปภาพไปให้ Java
      final result = await _channel.invokeMethod('printImageFromBytes', {
        'imageData': imageBytes, // ส่งข้อมูลรูปภาพจริง
        'portPath': '/dev/ttyS3',
      });

      setState(() => _status = result.toString());
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _printTestPattern() async {
    setState(() {
      _isPrinting = true;
      _status = 'Printing test...';
    });

    try {
      List<int> commands = [];

      // Simple test pattern
      commands.addAll(ESC_INIT);
      commands.addAll(ESC_ALIGN_CENTER);
      commands.addAll('=== TEST PRINT ===\n'.codeUnits);
      commands.addAll(ESC_ALIGN_LEFT);
      commands.addAll('Printer Width: $PRINTER_WIDTH dots\n'.codeUnits);
      commands.addAll('Port: $PORT_PATH\n'.codeUnits);
      commands.addAll(ESC_FEED_3);

      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(commands),
      });

      setState(() => _status = 'Test completed!');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _printCustom() async {
    setState(() {
      _isPrinting = true;
      _status = 'Sending custom data...';
    });

    try {
      // Example: Send raw hex data
      List<int> customData = [
        0x1B, 0x40, // ESC @
        // Add your custom commands here
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
        0x0A, // LF
        0x1B, 0x64, 0x03, // Feed 3 lines
      ];

      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(customData),
      });

      setState(() => _status = 'Custom data sent!');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _sendStartIgnoreProtocol() async {
    setState(() {
      _isPrinting = true;
      _status = 'Sending START_ignore_protocol...';
    });

    try {
      final result = await _channel.invokeMethod('sendStartIgnoreProtocol');
      setState(() => _status = result);
    } catch (e) {
      setState(() => _status = 'Protocol Error: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Printer - Raw Bytes Only'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isPrinting ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPrinting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // START_ignore_protocol button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _sendStartIgnoreProtocol,
                icon: const Icon(Icons.send),
                label: const Text('Send START_ignore_protocol'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.orange,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printTestPattern,
                icon: const Icon(Icons.text_snippet),
                label: const Text('Print Test Pattern'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printLargeImage,
                icon: const Icon(Icons.image),
                label: const Text('Print Logo Image'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printCustom,
                icon: const Icon(Icons.code),
                label: const Text('Send Custom Bytes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.purple,
                ),
              ),
            ),

            const Spacer(),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Port: /dev/ttyS3 | Width: 500 dots | Auto START_ignore_protocol on startup',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
