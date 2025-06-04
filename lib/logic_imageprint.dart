import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class ImagePrintLogic {
  static const String PORT_PATH = '/dev/ttyS3';
  static const int PRINTER_WIDTH = 500; // 50mm printer in dots
  
  // MethodChannel for printer communication
  static const MethodChannel _channel = MethodChannel('com.example.unittest/printer');
  
  /// Print multiple images from List<Uint8List>
  /// Returns true if successful, false if error
  static Future<bool> printImages(List<Uint8List> imageDataList) async {
    if (imageDataList.isEmpty) return false;
    
    try {
      // Initialize printer once
      await _initializePrinter();
      
      // Print each image
      for (int i = 0; i < imageDataList.length; i++) {
        final success = await _printSingleImage(imageDataList[i]);
        if (!success) return false;
        
        // Add spacing between images
        if (i < imageDataList.length - 1) {
          await _addImageSeparator();
        }
      }
      
      // Final cleanup
      await _finalizePrinting();
      
      return true;
    } catch (e) {
      print('Print error: $e');
      await _recoverFromError();
      return false;
    }
  }
  
  /// Print single image from Uint8List
  static Future<bool> printSingleImage(Uint8List imageData) async {
    try {
      await _initializePrinter();
      final success = await _printSingleImage(imageData);
      await _finalizePrinting();
      return success;
    } catch (e) {
      print('Print single image error: $e');
      await _recoverFromError();
      return false;
    }
  }
  
  /// Initialize printer with basic setup
  static Future<void> _initializePrinter() async {
    await _channel.invokeMethod('printBytes', {
      'portPath': PORT_PATH,
      'data': Uint8List.fromList([
        0x1B, 0x40, // ESC @ - Reset
        0x1B, 0x33, 0x00, // ESC 3 0 - Line spacing 0
      ]),
    });
    
    // Wait for printer to initialize
    await Future.delayed(const Duration(milliseconds: 50));
  }
  
  /// Process and print single image
  static Future<bool> _printSingleImage(Uint8List imageData) async {
    try {
      // 1. Decode image
      final originalImage = img.decodeImage(imageData);
      if (originalImage == null) {
        print('Failed to decode image');
        return false;
      }
      
      // 2. Calculate aspect ratio and resize proportionally
      final double aspectRatio = originalImage.width / originalImage.height;
      final int targetWidth = PRINTER_WIDTH;
      final int targetHeight = (targetWidth / aspectRatio * 0.4).round();
      
      final resizedImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // 3. Pre-process image to binary array
      final width = resizedImage.width;
      final height = resizedImage.height;
      final binaryData = List<int>.filled(width * height, 0);
      
      // Convert to binary (single pass)
      for (int i = 0; i < width * height; i++) {
        final y = i ~/ width;
        final x = i % width;
        final pixel = resizedImage.getPixel(x, y);
        binaryData[i] = img.getLuminance(pixel) < 128 ? 1 : 0;
      }
      
      // 4. Build and send print data using streaming approach
      const int maxBufferSize = 800;
      List<int> buffer = [];
      
      for (int y = 0; y < height; y += 8) {
        final rowData = <int>[];
        
        // Left half
        rowData.addAll([0x1B, 0x24, 0x00, 0x00, 0x1B, 0x2A, 0x01, 250, 0]);
        for (int x = 0; x < 250; x++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final pxY = y + bit;
            if (pxY < height && binaryData[pxY * width + x] == 1) {
              byte |= (1 << (7 - bit));
            }
          }
          rowData.add(byte);
        }
        
        // Right half
        rowData.addAll([0x1B, 0x24, 250, 0x00, 0x1B, 0x2A, 0x01, 250, 0]);
        for (int x = 250; x < 500 && x < width; x++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            final pxY = y + bit;
            if (pxY < height && binaryData[pxY * width + x] == 1) {
              byte |= (1 << (7 - bit));
            }
          }
          rowData.add(byte);
        }
        rowData.add(0x0A); // Line feed
        
        // Check buffer size and send if needed
        if (buffer.length + rowData.length > maxBufferSize) {
          if (buffer.isNotEmpty) {
            await _channel.invokeMethod('printBytes', {
              'portPath': PORT_PATH,
              'data': Uint8List.fromList(buffer),
            });
            buffer.clear();
            await Future.delayed(const Duration(milliseconds: 5));
          }
        }
        
        buffer.addAll(rowData);
      }
      
      // Send remaining data
      if (buffer.isNotEmpty) {
        await _channel.invokeMethod('printBytes', {
          'portPath': PORT_PATH,
          'data': Uint8List.fromList(buffer),
        });
      }
      
      return true;
    } catch (e) {
      print('Print single image error: $e');
      return false;
    }
  }
  
  /// Add separator between images
  static Future<void> _addImageSeparator() async {
    await _channel.invokeMethod('printBytes', {
      'portPath': PORT_PATH,
      'data': Uint8List.fromList([
        0x0A, 0x0A, 0x0A, // 3 line feeds
      ]),
    });
    await Future.delayed(const Duration(milliseconds: 20));
  }
  
  /// Finalize printing with reset
  static Future<void> _finalizePrinting() async {
    await Future.delayed(const Duration(milliseconds: 30));
    await _channel.invokeMethod('printBytes', {
      'portPath': PORT_PATH,
      'data': Uint8List.fromList([
        0x1B, 0x33, 0x18, // Reset line spacing
        0x1B, 0x40, // Final reset
      ]),
    });
  }
  
  /// Recover from error by resetting printer
  static Future<void> _recoverFromError() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList([0x1B, 0x40]), // Reset
      });
    } catch (resetError) {
      print('Reset error: $resetError');
    }
  }
  
  /// Print test pattern
  static Future<bool> printTestPattern() async {
    try {
      final commands = <int>[];
      
      // Simple test pattern
      commands.addAll([0x1B, 0x40]); // ESC @
      commands.addAll([0x1B, 0x61, 0x01]); // ESC a 1 - Center align
      commands.addAll('=== TEST PRINT ===\n'.codeUnits);
      commands.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - Left align
      commands.addAll('Printer Width: $PRINTER_WIDTH dots\n'.codeUnits);
      commands.addAll('Port: $PORT_PATH\n'.codeUnits);
      commands.addAll([0x1B, 0x64, 0x03]); // ESC d 3 - Feed 3 lines
      
      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(commands),
      });
      
      return true;
    } catch (e) {
      print('Test pattern error: $e');
      return false;
    }
  }
  
  /// Send custom bytes to printer
  static Future<bool> printCustomBytes(List<int> customData) async {
    try {
      await _channel.invokeMethod('printBytes', {
        'portPath': PORT_PATH,
        'data': Uint8List.fromList(customData),
      });
      return true;
    } catch (e) {
      print('Custom bytes error: $e');
      return false;
    }
  }
  
  /// Send START_ignore_protocol command
  static Future<String> sendStartIgnoreProtocol() async {
    try {
      final result = await _channel.invokeMethod('sendStartIgnoreProtocol');
      return result ?? 'Protocol sent successfully';
    } catch (e) {
      print('Protocol error: $e');
      return 'Protocol Error: $e';
    }
  }
}