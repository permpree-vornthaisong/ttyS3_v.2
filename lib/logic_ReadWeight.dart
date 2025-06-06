import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ Weight Reader แบบง่ายๆ เร็วที่สุด
class ReadWeightLogic extends ChangeNotifier {
  static const _channel = MethodChannel('com.example.unittest/printer_weight');

  // ✅ ตัวแปรเฉพาะที่จำเป็น
  String _weightData = 'ไม่มีข้อมูล';
  String _status = 'พร้อม';
  bool _isReading = false;
  String _currentPort = '/dev/ttyS8';
  int _currentBaudRate = 9600;
  Timer? _timer;
  int _readCount = 0;

  // ✅ Getters
  String get weightData => _weightData;
  String get status => _status;
  bool get isReading => _isReading;
  String get currentPort => _currentPort;
  int get currentBaudRate => _currentBaudRate;
  int get readCount => _readCount;

  /// ✅ เริ่มอ่านเร็วที่สุด
  Future<void> startFastReading() async {
    if (_isReading) {
      await stopReading();
    }

    _status = 'เริ่มอ่านเร็วที่สุด...';
    notifyListeners();

    try {
      // ✅ เริ่มอ่านใน Java
      await _channel.invokeMethod('startWeightReading', {
        'portPath': _currentPort,
        'baudRate': _currentBaudRate,
      });

      _isReading = true;
      _readCount = 0;

      // ✅ Timer เร็วที่สุด = 5ms
      _timer = Timer.periodic(Duration(milliseconds: 5), (timer) {
        _readFastData();
      });

      _status = 'อ่านเร็วที่สุด (5ms)';
      notifyListeners();
    } catch (e) {
      _status = 'Error: $e';
      notifyListeners();
    }
  }

  /// ✅ อ่านข้อมูลเร็วที่สุด - แสดงข้อมูลดิบทุกครั้ง
  Future<void> _readFastData() async {
    if (!_isReading) return;

    try {
      final data = await _channel.invokeMethod('readWeightData');

      if (data != null && data.toString().isNotEmpty) {
        // ✅ อัปเดตข้อมูลทุกครั้ง ไม่ว่าจะเหมือนเดิมหรือไม่
        _weightData = data.toString().trim();
        _readCount++;

        // ✅ อัปเดตสถานะง่ายๆ + แสดงข้อมูลดิบ
        final time = DateTime.now().toString().substring(11, 19);
        _status = '⚡ $time - อ่าน: $_readCount - Raw: $_weightData';

        // ✅ แจ้งให้ UI อัปเดตทุกครั้ง
        notifyListeners();
      } else {
        // ✅ แม้ไม่มีข้อมูลก็ยังนับและแสดงสถานะ
        _readCount++;
        final time = DateTime.now().toString().substring(11, 19);
        _status = '⚡ $time - ตรวจสอบ: $_readCount - ไม่มีข้อมูล';
        notifyListeners();
      }
    } catch (e) {
      // ✅ แสดง error แต่ไม่หยุดการอ่าน
      _readCount++;
      final time = DateTime.now().toString().substring(11, 19);
      _status = '❌ $time - Error: $e';
      notifyListeners();
      print('Read error: $e');
    }
  }

  /// ✅ หยุดอ่าน
  Future<void> stopReading() async {
    if (!_isReading) return;

    _timer?.cancel();
    _timer = null;

    try {
      await _channel.invokeMethod('stopWeightReading');
    } catch (e) {
      print('Stop error: $e');
    }

    _isReading = false;
    _status = 'หยุดแล้ว (อ่าน: $_readCount ครั้ง)';
    notifyListeners();
  }

  /// ✅ รีเซ็ต
  void reset() {
    _weightData = 'ไม่มีข้อมูล';
    _readCount = 0;
    _status = 'รีเซ็ตแล้ว';
    notifyListeners();
  }

  /// ✅ ดึงตัวเลขน้ำหนัก
  String getWeight() {
    if (_weightData.contains('WTST') && _weightData.contains('kg')) {
      final match = RegExp(r'([0-9]+\.?[0-9]*)\s*kg').firstMatch(_weightData);
      if (match != null) {
        return match.group(1) ?? '0.000';
      }
    }
    return '0.000';
  }

  /// ✅ เพิ่ม method getStatistics()
  String getStatistics() {
    return '''
Port: $_currentPort @ $_currentBaudRate
อ่านแล้ว: $_readCount ครั้ง
น้ำหนัก: ${getWeight()} kg
ข้อมูลดิบ: $_weightData
สถานะ: ${_isReading ? 'อ่านเร็วที่สุด' : 'หยุด'}
''';
  }

  @override
  void dispose() {
    stopReading();
    super.dispose();
  }
}
