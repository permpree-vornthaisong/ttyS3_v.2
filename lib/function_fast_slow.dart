// Future<void> _printLargeImage() async {
//   setState(() {
//     _isPrinting = true;
//     _status = 'Processing large image...';
//   });

//   try {
//     // 1. Load and decode image
//     final data = await rootBundle.load('assets/page_150.png');
//     final originalImage = img.decodeImage(data.buffer.asUint8List());
//     if (originalImage == null) throw Exception('Failed to decode image');

//     setState(() => _status = 'Resizing image...');

//     // 2. Calculate aspect ratio and resize proportionally
//     final double aspectRatio = originalImage.width / originalImage.height;
//     final int targetWidth = 500;
//     final int targetHeight = (targetWidth / aspectRatio * 0.4).round();

//     final resizedImage = img.copyResize(
//       originalImage,
//       width: targetWidth,
//       height: targetHeight,
//       interpolation: img.Interpolation.linear,
//     );

//     setState(() => _status = 'Processing image data...');

//     // 3. Get image dimensions
//     final width = resizedImage.width;
//     final height = resizedImage.height;

//     // Initialize printer
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList([0x1B, 0x40, 0x1B, 0x33, 0x00]),
//     });

//     // **Streaming approach** - ประมวลผลทีละแถวและส่งเลย
//     int processedRows = 0;
//     const int maxBufferSize = 800; // Max bytes per transmission
//     List<int> buffer = [];

//     for (int y = 0; y < height; y += 8) {
//       // Build row data
//       final rowData = <int>[];

//       // Left half
//       rowData.addAll([0x1B, 0x24, 0x00, 0x00, 0x1B, 0x2A, 0x01, 250, 0]);
//       for (int x = 0; x < 250; x++) {
//         int byte = 0;
//         for (int bit = 0; bit < 8; bit++) {
//           final pxY = y + bit;
//           if (pxY < height) {
//             final pixel = resizedImage.getPixel(x, pxY);
//             if (img.getLuminance(pixel) < 128) {
//               byte |= (1 << (7 - bit));
//             }
//           }
//         }
//         rowData.add(byte);
//       }

//       // Right half
//       rowData.addAll([0x1B, 0x24, 250, 0x00, 0x1B, 0x2A, 0x01, 250, 0]);
//       for (int x = 250; x < 500 && x < width; x++) {
//         int byte = 0;
//         for (int bit = 0; bit < 8; bit++) {
//           final pxY = y + bit;
//           if (pxY < height) {
//             final pixel = resizedImage.getPixel(x, pxY);
//             if (img.getLuminance(pixel) < 128) {
//               byte |= (1 << (7 - bit));
//             }
//           }
//         }
//         rowData.add(byte);
//       }
//       rowData.add(0x0A);

//       // เช็คว่าจะเกิน buffer หรือไม่
//       if (buffer.length + rowData.length > maxBufferSize) {
//         // ส่งข้อมูลที่มีใน buffer
//         if (buffer.isNotEmpty) {
//           await _channel.invokeMethod('printBytes', {
//             'portPath': '/dev/ttyS3',
//             'data': Uint8List.fromList(buffer),
//           });
//           buffer.clear();
//           await Future.delayed(const Duration(milliseconds: 10));
//         }
//       }

//       // เพิ่มข้อมูลแถวนี้เข้า buffer
//       buffer.addAll(rowData);
//       processedRows++;

//       // Update progress ทุก 8 แถว
//       if (processedRows % 8 == 0) {
//         final progress = (y / height * 100).round();
//         setState(() => _status = 'Streaming... $progress%');
//       }
//     }

//     // ส่งข้อมูลที่เหลือใน buffer
//     if (buffer.isNotEmpty) {
//       await _channel.invokeMethod('printBytes', {
//         'portPath': '/dev/ttyS3',
//         'data': Uint8List.fromList(buffer),
//       });
//     }

//     // Final reset
//     await Future.delayed(const Duration(milliseconds: 50));
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList([0x1B, 0x33, 0x18, 0x1B, 0x40]),
//     });

//     setState(() => _status = 'Large image printed successfully!');
//   } catch (e) {
//     setState(() => _status = 'Print error: $e');
//     debugPrint('Print error: $e');
//   } finally {
//     setState(() => _isPrinting = false);
//   }
// }


// Future<void> _printLargeImage() async {
//   setState(() {
//     _isPrinting = true;
//     _status = 'Processing large image...';
//   });

//   try {
//     // 1. Load and decode image
//     final data = await rootBundle.load('assets/page_150.png');
//     final originalImage = img.decodeImage(data.buffer.asUint8List());
//     if (originalImage == null) throw Exception('Failed to decode image');

//     setState(() => _status = 'Resizing image...');

//     // 2. Calculate aspect ratio and resize proportionally
//     final double aspectRatio = originalImage.width / originalImage.height;
//     final int targetWidth = 500;
//     final int targetHeight = (targetWidth / aspectRatio * 0.4).round();

//     final resizedImage = img.copyResize(
//       originalImage,
//       width: targetWidth,
//       height: targetHeight,
//       interpolation: img.Interpolation.linear,
//     );

//     setState(() => _status = 'Converting to binary...');

//     // 3. Pre-process ทั้งรูปเป็น binary array (เร็วกว่ามาก!)
//     final width = resizedImage.width;
//     final height = resizedImage.height;
//     final binaryData = List<int>.filled(width * height, 0);
    
//     // แปลงเป็น binary ก่อน (single pass)
//     for (int i = 0; i < width * height; i++) {
//       final y = i ~/ width;
//       final x = i % width;
//       final pixel = resizedImage.getPixel(x, y);
//       binaryData[i] = img.getLuminance(pixel) < 128 ? 1 : 0;
//     }

//     setState(() => _status = 'Building print data...');

//     // Initialize printer
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList([0x1B, 0x40, 0x1B, 0x33, 0x00]),
//     });

//     // 4. Build และส่งข้อมูลแบบ streaming (เร็วกว่า)
//     const int maxBufferSize = 800;
//     List<int> buffer = [];
//     int totalRows = (height / 8).ceil();
//     int currentRow = 0;

//     for (int y = 0; y < height; y += 8) {
//       final rowData = <int>[];

//       // Left half
//       rowData.addAll([0x1B, 0x24, 0x00, 0x00, 0x1B, 0x2A, 0x01, 250, 0]);
//       for (int x = 0; x < 250; x++) {
//         int byte = 0;
//         for (int bit = 0; bit < 8; bit++) {
//           final pxY = y + bit;
//           if (pxY < height && binaryData[pxY * width + x] == 1) {
//             byte |= (1 << (7 - bit));
//           }
//         }
//         rowData.add(byte);
//       }

//       // Right half
//       rowData.addAll([0x1B, 0x24, 250, 0x00, 0x1B, 0x2A, 0x01, 250, 0]);
//       for (int x = 250; x < 500 && x < width; x++) {
//         int byte = 0;
//         for (int bit = 0; bit < 8; bit++) {
//           final pxY = y + bit;
//           if (pxY < height && binaryData[pxY * width + x] == 1) {
//             byte |= (1 << (7 - bit));
//           }
//         }
//         rowData.add(byte);
//       }
//       rowData.add(0x0A);

//       // เช็ค buffer size
//       if (buffer.length + rowData.length > maxBufferSize) {
//         if (buffer.isNotEmpty) {
//           await _channel.invokeMethod('printBytes', {
//             'portPath': '/dev/ttyS3',
//             'data': Uint8List.fromList(buffer),
//           });
//           buffer.clear();
//           // ลด delay
//           await Future.delayed(const Duration(milliseconds: 5));
//         }
//       }

//       buffer.addAll(rowData);
//       currentRow++;

//       // Update progress น้อยลง
//       if (currentRow % 20 == 0) {
//         setState(() => _status = 'Printing... ${((currentRow / totalRows) * 100).round()}%');
//       }
//     }

//     // ส่งข้อมูลที่เหลือ
//     if (buffer.isNotEmpty) {
//       await _channel.invokeMethod('printBytes', {
//         'portPath': '/dev/ttyS3',
//         'data': Uint8List.fromList(buffer),
//       });
//     }

//     // Final reset
//     await Future.delayed(const Duration(milliseconds: 30));
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList([0x1B, 0x33, 0x18, 0x1B, 0x40]),
//     });

//     setState(() => _status = 'Large image printed successfully!');
//   } catch (e) {
//     setState(() => _status = 'Print error: $e');
//     debugPrint('Print error: $e');
//   } finally {
//     setState(() => _isPrinting = false);
//   }
// }



// Future<void> _printImage() async {
//   setState(() {
//     _isPrinting = true;
//     _status = 'Processing image...';
//   });

//   try {
//     // 1. Load image
//     final data = await rootBundle.load('assets/page_150.png');
//     final originalImage = img.decodeImage(data.buffer.asUint8List());
//     if (originalImage == null) throw Exception('Failed to decode image');

//     setState(() => _status = 'Resizing image...');

//     // 2. Calculate aspect ratio and resize proportionally
//     final double aspectRatio = originalImage.width / originalImage.height;
//     final int targetWidth = 500;
//     final int targetHeight = (targetWidth / aspectRatio * 0.4).round();

//     final resizedImage = img.copyResize(
//       originalImage,
//       width: targetWidth,
//       height: targetHeight,
//       interpolation: img.Interpolation.linear,
//     );

//     setState(() => _status = 'Converting to binary...');

//     final width = resizedImage.width;
//     final height = resizedImage.height;
    
//     // Initialize printer first
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList([
//         0x1B, 0x40, // Reset
//         0x1B, 0x33, 0x00, // Line spacing 0
//       ]),
//     });

//     await Future.delayed(const Duration(milliseconds: 100));

//     // แบ่งรูปเป็น 4 ส่วน
//     final totalRows = (height / 8).ceil();
//     final quarterSize = (totalRows / 4).ceil() * 8;

//     for (int quarter = 0; quarter < 4; quarter++) {
//       final startY = quarter * quarterSize;
//       final endY = ((quarter + 1) * quarterSize).clamp(0, height);
      
//       if (startY >= height) break;

//       setState(() => _status = 'Printing part ${quarter + 1}/4...');
//       final quarterData = <int>[];

//       for (int y = startY; y < endY; y += 8) {
//         // Left half command
//         quarterData.addAll([0x1B, 0x24, 0x00, 0x00]); // Position 0
//         quarterData.addAll([0x1B, 0x2A, 0x01, 250, 0]); // ESC * 250 bytes
        
//         // Process left half (0-249)
//         for (int x = 0; x < 250; x++) {
//           int byte = 0;
//           for (int bit = 0; bit < 8; bit++) {
//             final pxY = y + bit;
//             if (pxY < height) {
//               final pixel = resizedImage.getPixel(x, pxY);
//               if (img.getLuminance(pixel) < 128) {
//                 byte |= (1 << (7 - bit));
//               }
//             }
//           }
//           quarterData.add(byte);
//         }

//         // Right half command
//         quarterData.addAll([0x1B, 0x24, 250, 0x00]); // Position 250
//         quarterData.addAll([0x1B, 0x2A, 0x01, 250, 0]); // ESC * 250 bytes
        
//         // Process right half (250-499)
//         for (int x = 250; x < 500 && x < width; x++) {
//           int byte = 0;
//           for (int bit = 0; bit < 8; bit++) {
//             final pxY = y + bit;
//             if (pxY < height) {
//               final pixel = resizedImage.getPixel(x, pxY);
//               if (img.getLuminance(pixel) < 128) {
//                 byte |= (1 << (7 - bit));
//               }
//             }
//           }
//           quarterData.add(byte);
//         }
        
//         quarterData.add(0x0A); // Line feed
//       }

//       // ส่งข้อมูลส่วนนี้
//       await _channel.invokeMethod('printBytes', {
//         'portPath': '/dev/ttyS3',
//         'data': Uint8List.fromList(quarterData),
//       });

//       // รอให้ printer ประมวลผล
//       await Future.delayed(const Duration(milliseconds: 150));
//     }

//     // Final commands - รอนานกว่าเดิม
//     await Future.delayed(const Duration(milliseconds: 200));
    
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList([
//         0x1B, 0x33, 0x18, // Reset line spacing
//         0x0A, 0x0A, 0x0A, // Feed 3 lines
//         0x1B, 0x40, // Final reset
//       ]),
//     });

//     setState(() => _status = 'Image printed successfully!');
//   } catch (e) {
//     setState(() => _status = 'Print error: $e');
//     debugPrint('Print error: $e');
    
//     // Error recovery - เพิ่ม delay ก่อน reset
//     try {
//       await Future.delayed(const Duration(milliseconds: 500));
//       await _channel.invokeMethod('printBytes', {
//         'portPath': '/dev/ttyS3',
//         'data': Uint8List.fromList([0x1B, 0x40]), // Reset
//       });
//     } catch (resetError) {
//       debugPrint('Reset error: $resetError');
//     }
//   } finally {
//     setState(() => _isPrinting = false);
//   }
// }

// ปัญหา buffer overflow ยังคงเกิดขึ้นเพราะข้อมูลยังใหญ่เกินไป ลองแบ่งส่งเป็น 4 ส่วนแทน:



// Future<void> _printImage() async {
//   setState(() {
//     _isPrinting = true;
//     _status = 'Processing image...';
//   });

//   try {
//     // 1. Load image
//     final data = await rootBundle.load('assets/page_150.png');
//     final originalImage = img.decodeImage(data.buffer.asUint8List());
//     if (originalImage == null) throw Exception('Failed to decode image');

//     setState(() => _status = 'Resizing image...');

//     // 2. Calculate aspect ratio and resize proportionally
//     final double aspectRatio = originalImage.width / originalImage.height;
//     final int targetWidth = 500;
//     final int targetHeight = (targetWidth / aspectRatio * 0.4).round();

//     final resizedImage = img.copyResize(
//       originalImage,
//       width: targetWidth,
//       height: targetHeight,
//       interpolation: img.Interpolation.linear,
//     );

//     setState(() => _status = 'Converting to binary...');

//     // 3. Super fast conversion using direct pixel buffer access
//     final width = resizedImage.width;
//     final height = resizedImage.height;
    
//     // Pre-allocate all buffers
//     final printData = <int>[];
//     printData.addAll([0x1B, 0x40]); // Reset
//     printData.addAll([0x1B, 0x33, 0x00]); // Line spacing 0

//     // Convert image row by row and build print commands directly
//     for (int y = 0; y < height; y += 8) {
//       // Left half command
//       printData.addAll([0x1B, 0x24, 0x00, 0x00]); // Position 0
//       printData.addAll([0x1B, 0x2A, 0x01, 250, 0]); // ESC * 250 bytes
      
//       // Process left half (0-249)
//       for (int x = 0; x < 250; x++) {
//         int byte = 0;
//         for (int bit = 0; bit < 8; bit++) {
//           final pxY = y + bit;
//           if (pxY < height) {
//             final pixel = resizedImage.getPixel(x, pxY);
//             if (img.getLuminance(pixel) < 128) {
//               byte |= (1 << (7 - bit));
//             }
//           }
//         }
//         printData.add(byte);
//       }

//       // Right half command
//       printData.addAll([0x1B, 0x24, 250, 0x00]); // Position 250
//       printData.addAll([0x1B, 0x2A, 0x01, 250, 0]); // ESC * 250 bytes
      
//       // Process right half (250-499)
//       for (int x = 250; x < 500 && x < width; x++) {
//         int byte = 0;
//         for (int bit = 0; bit < 8; bit++) {
//           final pxY = y + bit;
//           if (pxY < height) {
//             final pixel = resizedImage.getPixel(x, pxY);
//             if (img.getLuminance(pixel) < 128) {
//               byte |= (1 << (7 - bit));
//             }
//           }
//         }
//         printData.add(byte);
//       }
      
//       printData.add(0x0A); // Line feed
      
//       // Update progress
//       if (y % 40 == 0) {
//         setState(() => _status = 'Processing... ${((y / height) * 100).round()}%');
//       }
//     }

//     // Final commands
//     printData.addAll([0x1B, 0x33, 0x18]); // Reset line spacing
//     printData.addAll([0x0A, 0x0A, 0x0A]); // Feed 3 lines

//     setState(() => _status = 'Sending to printer...');

//     // 4. Send all data at once
//     await _channel.invokeMethod('printBytes', {
//       'portPath': '/dev/ttyS3',
//       'data': Uint8List.fromList(printData),
//     });

//     setState(() => _status = 'Image printed successfully!');
//   } catch (e) {
//     setState(() => _status = 'Print error: $e');
//     debugPrint('Print error: $e');
    
//     // Error recovery
//     try {
//       await _channel.invokeMethod('printBytes', {
//         'portPath': '/dev/ttyS3',
//         'data': Uint8List.fromList([0x1B, 0x40]),
//       });
//     } catch (resetError) {
//       debugPrint('Reset error: $resetError');
//     }
//   } finally {
//     setState(() => _isPrinting = false);
//   }
// }