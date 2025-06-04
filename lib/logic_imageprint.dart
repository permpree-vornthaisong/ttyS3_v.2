import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

class ImagePrintLogic extends ChangeNotifier {
  bool _isProcessing = false;
  String _status = 'Ready';
  Uint8List? _pdfBytes;
  List<Uint8List>? _imageBytes;
  String? _message;

  // Getters
  bool get isProcessing => _isProcessing;
  String get status => _status;
  Uint8List? get pdfBytes => _pdfBytes;
  List<Uint8List>? get imageBytes => _imageBytes;
  String? get message => _message;

  /// Update state
  void _updateState(String status, {bool? processing}) {
    _status = status;
    if (processing != null) _isProcessing = processing;
    notifyListeners();
  }

  /// สร้างรูปภาพเดียวจาก JSON (Main Method)
  Future<Uint8List?> createReceiptImage(Map<String, dynamic> jsonData) async {
    try {
      print('🔍 DEBUG: Starting createReceiptImage');
      _updateState('กำลังสร้างรูปภาพ...', processing: true);

      // 1. Generate PDF from JSON
      await generateReceiptFromJson(jsonData);

      if (_pdfBytes == null) {
        throw Exception('Failed to generate PDF');
      }
      print('🔍 DEBUG: PDF created, size: ${_pdfBytes!.length} bytes');

      // 2. Convert PDF to Images
      await convertPdfToImages(dpi: 150);

      if (_imageBytes == null || _imageBytes!.isEmpty) {
        throw Exception('Failed to convert PDF to images');
      }

      // 3. Return first image
      final firstImage = _imageBytes![0];
      print('🔍 DEBUG: Image created, size: ${firstImage.length} bytes');

      _updateState('สร้างรูปภาพสำเร็จ');
      return firstImage;
    } catch (e) {
      print('🔴 ERROR: $e');
      _updateState('เกิดข้อผิดพลาด: $e');
      return null;
    } finally {
      _updateState(_status, processing: false);
    }
  }

  /// Generate PDF from JSON data
  Future<void> generateReceiptFromJson(Map<String, dynamic> jsonData) async {
    _updateState('กำลังสร้าง PDF จาก JSON...', processing: true);

    try {
      final document = PdfDocument();
      const pageWidth = 250.0; // 500px width เหมือน pdf_state.dart

      // Extract items from JSON (หรือสร้างข้อมูลตัวอย่าง)
      final items = _parseItems(jsonData['items']);

      // คำนวณความสูงตามจำนวนรายการ
      final itemHeight = 30.0;
      final headerHeight = 150.0;
      final footerHeight = 100.0;
      final totalHeight =
          headerHeight + (items.length * itemHeight + 600) + footerHeight;

      // กำหนดขนาดหน้ากระดาษแบบไดนามิก
      document.pageSettings.size = Size(pageWidth, totalHeight);

      final page = document.pages.add();

      // ✅ โหลด Thai font เหมือน pdf_state.dart
      final fontData = await rootBundle.load('assets/fonts/ZoodRangmah3.1.ttf');
      final thaiFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 14);
      final thaiFontBold = PdfTrueTypeFont(fontData.buffer.asUint8List(), 16);

      double y = 0;

      // ✅ เพิ่มพื้นหลังสีขาว
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(0, 0, pageWidth, totalHeight),
      );

      // วาดส่วนหัว
      final title = jsonData['title']?.toString() ?? 'ใบเสร็จรับเงิน';
      page.graphics.drawString(
        title,
        thaiFontBold,
        bounds: Rect.fromLTWH(pageWidth / 2 - 100, y, 200, 30),
      );
      y += 50;

      // วันที่
      final dateStr = jsonData['date']?.toString() ??
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      page.graphics.drawString(
        'วันที่: $dateStr',
        thaiFont,
        bounds: Rect.fromLTWH(0, y, 200, 20),
      );
      y += 40;

      // หัวตาราง
      page.graphics.drawString(
        'รายการสินค้า',
        thaiFontBold,
        bounds: Rect.fromLTWH(0, y, 300, 30),
      );
      page.graphics.drawString(
        'ราคา',
        thaiFontBold,
        bounds: Rect.fromLTWH(170, y, 100, 30),
      );
      y += 40;

      // วาดเส้นคั่น
      page.graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0)),
        Offset(0, y),
        Offset(pageWidth - 50, y),
      );
      y += 20;

      // วาดรายการสินค้า
      double total = 0;
      for (var item in items) {
        page.graphics.drawString(
          item['name'] as String,
          thaiFont,
          bounds: Rect.fromLTWH(0, y, 150, itemHeight),
        );
        page.graphics.drawString(
          '฿${(item['price'] as double).toStringAsFixed(2)}',
          thaiFont,
          bounds: Rect.fromLTWH(170, y, 100, itemHeight),
        );
        total += item['price'] as double;
        y += itemHeight;
      }

      // วาดส่วนท้าย
      y += 20;
      page.graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0)),
        Offset(50, y),
        Offset(pageWidth - 50, y),
      );
      y += 20;

      // ยอดรวม
      page.graphics.drawString(
        'รวมทั้งสิ้น:',
        thaiFontBold,
        bounds: Rect.fromLTWH(0, y, 100, 30),
      );
      page.graphics.drawString(
        '฿${total.toStringAsFixed(2)}',
        thaiFontBold,
        bounds: Rect.fromLTWH(100, y, 100, 30),
      );

      _pdfBytes = Uint8List.fromList(document.saveSync());
      _message = 'สร้าง PDF สำเร็จ';
      document.dispose();

      _updateState('สร้าง PDF สำเร็จ');
    } catch (e) {
      _message = 'เกิดข้อผิดพลาดในการสร้าง PDF: $e';
      _updateState('เกิดข้อผิดพลาด: $e');
    } finally {
      _updateState(_status, processing: false);
    }
  }

  /// Convert PDF to Images (เหมือน pdf_state.dart)
  Future<void> convertPdfToImages({double dpi = 150}) async {
    if (_pdfBytes == null) {
      _updateState('ไม่มี PDF ให้แปลง');
      return;
    }

    _updateState('กำลังแปลง PDF เป็น Images...', processing: true);

    try {
      final images = <Uint8List>[];
      int processedPages = 0;

      await for (final page in Printing.raster(_pdfBytes!, dpi: dpi)) {
        processedPages++;
        _updateState('กำลังแปลงหน้า $processedPages...', processing: true);

        // ✅ ใช้ method เดียวกับ pdf_state.dart
        final imageData = await _createImageWithWhiteBackground(page);
        images.add(imageData);
      }

      _imageBytes = images;
      _updateState('แปลง PDF เป็น Images สำเร็จ (${images.length} หน้า)');
    } catch (e) {
      _updateState('เกิดข้อผิดพลาดในการแปลง: $e');
    } finally {
      _updateState(_status, processing: false);
    }
  }

  /// สร้างรูปภาพพื้นหลังสีขาว (เหมือน pdf_state.dart แต่เป็นสีขาว)
  Future<Uint8List> _createImageWithWhiteBackground(PdfRaster page) async {
    try {
      final originalImageBytes = await page.toPng();
      final originalImage = img.decodeImage(originalImageBytes);
      if (originalImage == null) {
        return originalImageBytes;
      }

      const double widthMultiplier = 1;
      final newWidth = (originalImage.width * widthMultiplier).round();
      final newHeight = originalImage.height;

      final newImage = img.Image(width: newWidth, height: newHeight);

      // ✅ Fill with white background (แทนที่จะเป็นสีดำ)
      img.fill(newImage, color: img.ColorRgb8(255, 255, 255));

      final offsetX = ((newWidth - originalImage.width) / 2).round();
      final offsetY = 0;

      img.compositeImage(newImage, originalImage, dstX: offsetX, dstY: offsetY);

      final pngBytes = img.encodePng(newImage);
      return Uint8List.fromList(pngBytes);
    } catch (e) {
      print('Error processing image: $e');
      return await page.toPng();
    }
  }

  /// Parse items from JSON
  List<Map<String, dynamic>> _parseItems(dynamic itemsData) {
    if (itemsData is List) {
      return itemsData
          .map((item) => {
                'name': item['name']?.toString() ?? 'รายการ',
                'price': (item['price'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();
    }

    // Generate sample data if no items provided
    return _generateSampleItems(2);
  }

  /// Generate sample items (เหมือน pdf_state.dart)
  List<Map<String, dynamic>> _generateSampleItems(int count) {
    return List.generate(
        count,
        (index) => {
              'name': 'สินค้า ${index + 1}',
              'price': (Random().nextDouble() * 1000).roundToDouble(),
            });
  }

  /// Clear data
  void clearData() {
    _pdfBytes = null;
    _imageBytes = null;
    _message = null;
    _updateState('Ready');
  }

  /// สร้าง PDF จาก JSON (ส่งไป Java แปลงเป็นรูป) - ✅ เพิ่มใหม่
  Future<Uint8List?> createReceiptPDF(Map<String, dynamic> jsonData) async {
    try {
      print('🔍 DEBUG: Starting createReceiptPDF');
      _updateState('กำลังสร้าง PDF...', processing: true);

      // Generate PDF from JSON
      await generateReceiptFromJson(jsonData);

      if (_pdfBytes == null) {
        throw Exception('Failed to generate PDF');
      }
      print('🔍 DEBUG: PDF created, size: ${_pdfBytes!.length} bytes');

      _updateState('สร้าง PDF สำเร็จ');
      return _pdfBytes;
    } catch (e) {
      print('🔴 ERROR: $e');
      _updateState('เกิดข้อผิดพลาด: $e');
      return null;
    } finally {
      _updateState(_status, processing: false);
    }
  }
}
