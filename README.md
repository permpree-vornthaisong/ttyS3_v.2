GitHub Copilot: # Flutter Thermal Printer Project (ttyS3_v.2)

## 📋 Project Overview
Real name: **unittest**  
Flutter application สำหรับการพิมพ์ใบเสร็จ/รูปภาพผ่าน thermal printer ที่เชื่อมต่อ serial port

## 🛠️ Technologies Used

### Frontend (Flutter/Dart)
- **Flutter SDK** - Framework หลัก
- **Dart** - Programming language
- **Provider** - State management (ใช้ ChangeNotifier)

### PDF & Image Processing
- **syncfusion_flutter_pdf: ^26.2.14** - สร้าง PDF
- **printing: ^5.12.0** - แปลง PDF เป็นรูปภาพ
- **image: ^4.1.7** - ประมวลผลรูปภาพ
- **intl: ^0.19.0** - จัดการวันที่และเวลา

### Backend (Android/Java)
- **Native Java** - ประมวลผล PDF และส่งข้อมูลไป serial port
- **PdfRenderer** - แปลง PDF เป็น Bitmap
- **MethodChannel** - สื่อสารระหว่าง Flutter และ Java

### File & Storage
- **path_provider: ^2.1.4** - จัดการ path ไฟล์
- **sqflite: ^2.3.2** - Database (อยู่ใน dependencies แต่ยังไม่ได้ใช้)

### UI Components
- **flutter_svg: ^2.0.10+1** - แสดง SVG images
- **google_fonts: 6.1.0** - Font family (อยู่ใน dependencies แต่ใช้ custom font แทน)

### Utilities
- **file_picker: ^6.2.0** - เลือกไฟล์
- **permission_handler: ^11.3.0** - จัดการ permissions
- **usb_serial: ^0.5.1** - USB serial communication
- **excel: ^3.0.0** - จัดการไฟล์ Excel
- **datepicker_dropdown: ^0.1.0** - Date picker widget

## 📁 Core Files Structure

### ✅ Files Being Used
```
lib/
├── main.dart                    # Main app entry point
├── logic_imageprint.dart        # PDF/Image generation logic
└── assets/
    ├── fonts/
    │   └── ZoodRangmah3.1.ttf   # Thai font
    └── LOGOq.jpg                # Receipt logo

android/app/src/main/java/io/flutter/plugins/com/example/unittest/
├── MainActivity.java            # Main Android activity
└── PrinterNative.java          # Native printer implementation
```

### ❌ Files Not Used (But Available)
```
android/app/src/main/java/io/flutter/plugins/com/example/unittest/
├── WeightReader.java           # Scale/weight reading (not used)
└── SerialCommandSender.java    # Serial commands (not used)
```

## 🎯 Main Features

### 1. PDF Receipt Generation
- สร้างใบเสร็จ PDF จาก JSON data
- รองรับ Thai font (ZoodRangmah)
- เพิ่มโลโก้อัตโนมัติ
- คำนวณขนาดหน้ากระดาษแบบ dynamic

### 2. Image Processing
- แปลง PDF เป็นรูปภาพ PNG
- ปรับขนาดอัตโนมัติ (500px width)
- จัดกึ่งกลางบนกระดาษ thermal
- ประมวลผลสี (Black & White)

### 3. Printing Methods
| Method | Technology | Use Case |
|--------|------------|----------|
| **printImageFromBytes** | Java Native | รูปภาพ Uint8List |
| **printPdfAsImage** | Java Native | PDF → Image → Print |
| **printPdfAsImageAutoResize** | Java Native | Auto-resize + centering |

### 4. Thermal Printer Support
- Serial port communication (/dev/ttyS3)
- ESC/POS commands
- 500px width (250px x 2 halves)
- Buffer management

## 📊 Data Flow

```mermaid
graph LR
    A[JSON Data] --> B[PDF Generation]
    B --> C[PDF to Image]
    C --> D[Image Processing]
    D --> E[Java Native]
    E --> F[Thermal Printer]
```

## 🔧 Installation & Usage

### Build APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Install on Device
```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### macOS Development Setup
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install ADB
brew install android-platform-tools
```

## 📱 App Functions

### Available Buttons
1. **Print PDF via Java** - ส่ง PDF ไป Java แปลงและพิมพ์
2. **Print via Flutter** - สร้างรูปใน Flutter แล้วพิมพ์

### Sample JSON Data
```json
{
  "title": "ใบเสร็จรับเงิน",
  "date": "04/06/2025", 
  "items": [
    {"name": "กาแฟ", "price": 50.0},
    {"name": "ขนม", "price": 25.0}
  ]
}
```

## ⚠️ Dependencies Not Used

### In pubspec.yaml but not implemented:
- **sqflite** - Database functionality planned but not used
- **google_fonts** - Replaced with custom Thai font
- **excel** - Excel file processing not implemented
- **file_picker** - File selection not implemented in current UI
- **permission_handler** - Permissions not explicitly requested
- **usb_serial** - USB serial not used (using file-based serial)
- **datepicker_dropdown** - Date picker not used in current UI

### Java classes available but not used:
- **WeightReader.java** - Scale reading functionality
- **SerialCommandSender.java** - Serial protocol commands

## 🎯 Performance Stats
- **Font Optimization**: MaterialIcons reduced 99.9% (1.6MB → 1.2KB)
- **APK Size**: 23.1MB (Release build)
- **Build Time**: ~31.7 seconds
- **Image Size**: ~20KB (optimal for thermal printing)

## 🔬 Debug Features
- Console logging for all major operations
- Error handling with Thai messages
- Status updates in real-time
- PDF/Image size tracking

---

**สรุป**: โปรเจคนี้เป็น complete solution สำหรับการพิมพ์ใบเสร็จ thermal printer โดยใช้ Flutter + Java Native ทำงานร่วมกัน มี dependencies บางตัวที่ยังไม่ได้ใช้แต่เตรียมไว้สำหรับ features ในอนาคต

permpree-vornthaisong: มีตัวอะไรไม่ได้ใช้บ้าง

GitHub Copilot: ## ⚠️ Dependencies และ Files ที่ไม่ได้ใช้

### 📦 **Dependencies ใน pubspec.yaml ที่ไม่ได้ใช้**

| Package | Version | สถานะ | เหตุผล |
|---------|---------|-------|--------|
| **sqflite** | ^2.3.2 | ❌ ไม่ได้ใช้ | วางแผนใช้เก็บข้อมูลแต่ยังไม่ implement |
| **google_fonts** | 6.1.0 | ❌ ไม่ได้ใช้ | ใช้ custom Thai font แทน |
| **excel** | ^3.0.0 | ❌ ไม่ได้ใช้ | วางแผน import/export Excel |
| **file_picker** | ^6.2.0 | ❌ ไม่ได้ใช้ | UI ปัจจุบันไม่มีการเลือกไฟล์ |
| **permission_handler** | ^11.3.0 | ❌ ไม่ได้ใช้ | ไม่ได้ request permissions อย่างชัดเจน |
| **usb_serial** | ^0.5.1 | ❌ ไม่ได้ใช้ | ใช้ file-based serial แทน |
| **datepicker_dropdown** | ^0.1.0 | ❌ ไม่ได้ใช้ | UI ไม่มี date picker |
| **flutter_svg** | ^2.0.10+1 | ❌ ไม่ได้ใช้ | ใช้ JPG logo แทน SVG |

### 🗂️ **Files ที่ไม่ได้ใช้**

#### Java Classes
```java
android/app/src/main/java/io/flutter/plugins/com/example/unittest/
├── WeightReader.java           # อ่านค่าน้ำหนักจากเครื่องชั่ง
└── SerialCommandSender.java    # ส่งคำสั่ง serial protocol
```

#### Assets ที่อาจไม่ได้ใช้
```
assets/
├── images/               # อาจมีรูปอื่นๆ ที่ไม่ได้ใช้
└── *.pdf               # PDF ตัวอย่างที่อาจไม่จำเป็น
```

### 🎯 **ส่วนที่อาจลบได้**

#### 1. **Dependencies ที่ลบได้ทันที**
```yaml
# ใน pubspec.yaml - ลบได้
dependencies:
  # google_fonts: 6.1.0          # ❌ ลบได้
  # datepicker_dropdown: ^0.1.0  # ❌ ลบได้  
  # flutter_svg: ^2.0.10+1       # ❌ ลบได้
```

#### 2. **Dependencies ที่ควรเก็บไว้ (Future use)**
```yaml
# เก็บไว้สำหรับ features ในอนาคต
dependencies:
  sqflite: ^2.3.2              # ✅ เก็บไว้ - Database
  excel: ^3.0.0                # ✅ เก็บไว้ - Excel import/export
  file_picker: ^6.2.0          # ✅ เก็บไว้ - File selection
  permission_handler: ^11.3.0  # ✅ เก็บไว้ - Permissions
  usb_serial: ^0.5.1           # ✅ เก็บไว้ - USB communication
```

#### 3. **Java Files ที่ลบได้**
```bash
# ลบได้ถ้าไม่ใช้
rm android/app/src/main/java/io/flutter/plugins/com/example/unittest/WeightReader.java
rm android/app/src/main/java/io/flutter/plugins/com/example/unittest/SerialCommandSender.java
```

### 📊 **สรุปการใช้งานจริง**

#### ✅ **ใช้งานจริง (8 packages)**
- **flutter/dart** - Core framework
- **syncfusion_flutter_pdf** - PDF generation
- **printing** - PDF to image
- **image** - Image processing  
- **intl** - Date/time formatting
- **path_provider** - File paths

#### ❌ **ไม่ได้ใช้ (8 packages)**
- **sqflite** - Database
- **google_fonts** - Fonts
- **excel** - Excel files
- **file_picker** - File selection
- **permission_handler** - Permissions
- **usb_serial** - USB communication
- **datepicker_dropdown** - Date picker
- **flutter_svg** - SVG images

### 🛠️ **แนะนำการทำความสะอาด**

```yaml
# pubspec.yaml - เวอร์ชันที่ทำความสะอาดแล้ว
dependencies:
  flutter:
    sdk: flutter
    
  # PDF & Image Processing (ใช้งานจริง)
  syncfusion_flutter_pdf: ^26.2.14
  printing: ^5.12.0
  image: ^4.1.7
  intl: ^0.19.0
  path_provider: ^2.1.4
  
  # Future features (เก็บไว้)
  sqflite: ^2.3.2
  excel: ^3.0.0
  file_picker: ^6.2.0
  permission_handler: ^11.3.0
  usb_serial: ^0.5.1
  
  # ลบออก (ไม่จำเป็น)
  # google_fonts: 6.1.0
  # datepicker_dropdown: ^0.1.0
  # flutter_svg: ^2.0.10+1
```

**ผลลัพธ์**: ลดขนาด APK และเพิ่มความเร็วในการ build! 🚀