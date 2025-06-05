package com.example.unittest;

import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.util.ArrayList;

// เพิ่ม imports ใหม่เหล่านี้
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.pdf.PdfRenderer;
import android.os.ParcelFileDescriptor;

public class MainActivity extends FlutterActivity {

    private static final String PRINTER_CHANNEL = "com.example.unittest/printer";
    private static final String WEIGHT_CHANNEL = "com.example.unittest/printer_weight";
    private static final String TAG = "MainActivity";

    private PrinterNative printerNative;
    private WeightReader weightReader;
    private SerialCommandSender commandSender;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        printerNative = new PrinterNative();
        weightReader = new WeightReader();
        commandSender = new SerialCommandSender();

        // Send START_ignore_protocol twice on app startup
        sendStartIgnoreProtocolOnStartup();

        // MethodChannel for Printer operations
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                PRINTER_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "getPorts":
                    ArrayList<String> ports = new ArrayList<>();
                    File dev = new File("/dev");
                    File[] files = dev.listFiles((dir, name) -> name.startsWith("tty"));
                    if (files != null) {
                        for (File file : files) {
                            ports.add(file.getAbsolutePath());
                        }
                    }
                    result.success(ports);
                    break;

                case "printBytes":
                    String portPath = call.argument("portPath");
                    byte[] data = call.argument("data");

                    if (portPath == null || data == null) {
                        result.error("INVALID_ARGUMENTS", "Port path and data required", null);
                        return;
                    }

                    boolean success = printerNative.printBytes(portPath, data);
                    if (success) {
                        result.success(true);
                    } else {
                        result.error("PRINT_ERROR", "Failed to print bytes", null);
                    }
                    break;

                case "printImageFast":
                    String assetPath = call.argument("assetPath");
                    portPath = call.argument("portPath");
                    printImageFast(assetPath, portPath, result);
                    break;

                case "printImageFromBytes":
                    byte[] imageData = call.argument("imageData");
                    portPath = call.argument("portPath");
                    printImageFromBytes(imageData, portPath, result);
                    break;

                case "sendStartIgnoreProtocol":
                    boolean protocolSuccess = commandSender.sendStartIgnoreProtocol();
                    if (protocolSuccess) {
                        result.success("START_ignore_protocol sent successfully");
                    } else {
                        result.error("PROTOCOL_ERROR", "Failed to send START_ignore_protocol", null);
                    }
                    break;

                // ✅ แก้ไขใน switch case ของ PRINTER_CHANNEL
                case "printPdfAsImage":
                    byte[] pdfData = call.argument("pdfData");
                    portPath = call.argument("portPath");
                    Integer dpi = call.argument("dpi");
                    // ❌ ลบ paperWidth parameter ออก
                    
                    if (pdfData == null || portPath == null) {
                        result.error("INVALID_ARGUMENTS", "PDF data and port path required", null);
                        return;
                    }
                    
                    printPdfAsImage(pdfData, portPath, 
                                   dpi != null ? dpi : 150, 
                                   result);
                    break;
   // ✅ เพิ่ม case ใหม่
                case "printPdfAsImageAutoResize":
                    byte[] pdfDataAuto = call.argument("pdfData");
                    portPath = call.argument("portPath");
                    Integer dpiAuto = call.argument("dpi");
                    
                    if (pdfDataAuto == null || portPath == null) {
                        result.error("INVALID_ARGUMENTS", "PDF data and port path required", null);
                        return;
                    }
                    
                    printPdfAsImageAutoResize(pdfDataAuto, portPath, 
                                             dpiAuto != null ? dpiAuto : 150, 
                                             result);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });

        // MethodChannel for WeightReader operations
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                WEIGHT_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "readWeight":
                    String portPath = call.argument("portPath");
                    Integer baudRateInteger = call.argument("baudRate");

                    if (portPath == null || baudRateInteger == null) {
                        result.error("INVALID_ARGUMENTS",
                                "Port path and baud rate required", null);
                        return;
                    }

                    int baudRate = baudRateInteger.intValue();
                    String rawData = weightReader.readAndLogRawData(portPath, baudRate);

                    if (rawData != null) {
                        result.success(rawData);
                    } else {
                        result.error("READ_ERROR",
                                "Failed to read raw data from scale", null);
                    }
                    break;

                case "closeWeightPort":
                    weightReader.closePort();
                    result.success("Weight port closed");
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void sendStartIgnoreProtocolOnStartup() {
        new Thread(() -> {
            try {
                Thread.sleep(1000);
                Log.d(TAG, "Sending START_ignore_protocol on app startup...");
                boolean success = commandSender.sendStartIgnoreProtocol();
                if (success) {
                    Log.d(TAG, "START_ignore_protocol sent successfully on startup");
                } else {
                    Log.e(TAG, "Failed to send START_ignore_protocol on startup");
                }
            } catch (InterruptedException e) {
                Log.e(TAG, "Interrupted while sending startup protocol: " + e.getMessage());
            }
        }).start();
    }

    private void printImageFast(String assetPath, String portPath, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                // 1. Load image from assets
                InputStream inputStream = getAssets().open(assetPath);
                Bitmap originalBitmap = BitmapFactory.decodeStream(inputStream);
                inputStream.close();

                if (originalBitmap == null) {
                    result.error("DECODE_ERROR", "Failed to decode image", null);
                    return;
                }

                // 2. Resize image
                float aspectRatio = (float) originalBitmap.getWidth() / originalBitmap.getHeight();
                int targetWidth = 500;
                int targetHeight = (int) (targetWidth / aspectRatio * 0.4f);
                
                Bitmap resizedBitmap = Bitmap.createScaledBitmap(
                    originalBitmap, targetWidth, targetHeight, true);
                originalBitmap.recycle();

                // 3. Convert to binary data
                int width = resizedBitmap.getWidth();
                int height = resizedBitmap.getHeight();
                byte[] binaryData = new byte[width * height];
                
                int[] pixels = new int[width * height];
                resizedBitmap.getPixels(pixels, 0, width, 0, 0, width, height);
                
                for (int i = 0; i < pixels.length; i++) {
                    int luminance = (Color.red(pixels[i]) + Color.green(pixels[i]) + Color.blue(pixels[i])) / 3;
                    binaryData[i] = (byte) (luminance < 128 ? 1 : 0);
                }
                
                resizedBitmap.recycle();

                // 4. Print to serial port
                try (FileOutputStream fos = new FileOutputStream(portPath)) {
                    // Initialize printer
                    fos.write(new byte[]{0x1B, 0x40, 0x1B, 0x33, 0x00});
                    fos.flush();
                    Thread.sleep(250);

                    // Process and send data
                    byte[] buffer = new byte[512];
                    int bufferPos = 0;
                    
                    for (int y = 0; y < height; y += 8) {
                        // Left half command
                        byte[] leftCmd = {0x1B, 0x24, 0x00, 0x00, 0x1B, 0x2A, 0x01, (byte)250, 0};
                        
                        if (bufferPos + leftCmd.length + 250 > buffer.length) {
                            fos.write(buffer, 0, bufferPos);
                            fos.flush();
                            bufferPos = 0;
                            Thread.sleep(50);
                        }
                        
                        System.arraycopy(leftCmd, 0, buffer, bufferPos, leftCmd.length);
                        bufferPos += leftCmd.length;
                        
                        // Process left half (0-249)
                        for (int x = 0; x < 250; x++) {
                            byte pixelByte = 0;
                            for (int bit = 0; bit < 8; bit++) {
                                int pxY = y + bit;
                                if (pxY < height && x < width && binaryData[pxY * width + x] == 1) {
                                    pixelByte |= (1 << (7 - bit));
                                }
                            }
                            buffer[bufferPos++] = pixelByte;
                        }
                        
                        // Right half command
                        byte[] rightCmd = {0x1B, 0x24, (byte)250, 0x00, 0x1B, 0x2A, 0x01, (byte)250, 0};
                        
                        if (bufferPos + rightCmd.length + 250 + 1 > buffer.length) {
                            fos.write(buffer, 0, bufferPos);
                            fos.flush();
                            bufferPos = 0;
                            Thread.sleep(50);
                        }
                        
                        System.arraycopy(rightCmd, 0, buffer, bufferPos, rightCmd.length);
                        bufferPos += rightCmd.length;
                        
                        // Process right half (250-499)
                        for (int x = 250; x < 500 && x < width; x++) {
                            byte pixelByte = 0;
                            for (int bit = 0; bit < 8; bit++) {
                                int pxY = y + bit;
                                if (pxY < height && binaryData[pxY * width + x] == 1) {
                                    pixelByte |= (1 << (7 - bit));
                                }
                            }
                            buffer[bufferPos++] = pixelByte;
                        }
                        
                        buffer[bufferPos++] = 0x0A; // Line feed
                    }
                    
                    // Send remaining data
                    if (bufferPos > 0) {
                        fos.write(buffer, 0, bufferPos);
                        fos.flush();
                    }
                    
                    // Final commands
                    Thread.sleep(60);
                    fos.write(new byte[]{0x1B, 0x33, 0x18, 0x1B, 0x40});
                    fos.flush();
                    
                    result.success("Image printed successfully with Java native code!");
                    
                } catch (IOException e) {
                    result.error("PRINT_ERROR", "Print failed: " + e.getMessage(), null);
                }
                
            } catch (Exception e) {
                result.error("ERROR", "Failed to print image: " + e.getMessage(), null);
            }
        }).start();
    }

    private void printImageFromBytes(byte[] imageData, String portPath, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                // 1. Decode image จาก byte array
                Bitmap originalBitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.length);
                
                if (originalBitmap == null) {
                    result.error("DECODE_ERROR", "Failed to decode image from bytes", null);
                    return;
                }

                // 2. Resize image
                float aspectRatio = (float) originalBitmap.getWidth() / originalBitmap.getHeight();
                int targetWidth = 500;
                int targetHeight = (int) (targetWidth / aspectRatio * 0.4f);
                
                Bitmap resizedBitmap = Bitmap.createScaledBitmap(
                    originalBitmap, targetWidth, targetHeight, true);
                originalBitmap.recycle();

                // 3. Convert to binary data
                int width = resizedBitmap.getWidth();
                int height = resizedBitmap.getHeight();
                byte[] binaryData = new byte[width * height];
                
                int[] pixels = new int[width * height];
                resizedBitmap.getPixels(pixels, 0, width, 0, 0, width, height);
                
                for (int i = 0; i < pixels.length; i++) {
                    int luminance = (Color.red(pixels[i]) + Color.green(pixels[i]) + Color.blue(pixels[i])) / 3;
                    binaryData[i] = (byte) (luminance < 128 ? 1 : 0);
                }
                
                resizedBitmap.recycle();

                // 4. Print to serial port
                try (FileOutputStream fos = new FileOutputStream(portPath)) {
                    // Initialize printer
                    fos.write(new byte[]{0x1B, 0x40, 0x1B, 0x33, 0x00});
                    fos.flush();
                    Thread.sleep(250);

                    // Process and send data
                    byte[] buffer = new byte[512];
                    int bufferPos = 0;
                    
                    for (int y = 0; y < height; y += 8) {
                        // Left half command
                        byte[] leftCmd = {0x1B, 0x24, 0x00, 0x00, 0x1B, 0x2A, 0x01, (byte)250, 0};
                        
                        if (bufferPos + leftCmd.length + 250 > buffer.length) {
                            fos.write(buffer, 0, bufferPos);
                            fos.flush();
                            bufferPos = 0;
                            Thread.sleep(50);
                        }
                        
                        System.arraycopy(leftCmd, 0, buffer, bufferPos, leftCmd.length);
                        bufferPos += leftCmd.length;
                        
                        // Process left half (0-249)
                        for (int x = 0; x < 250; x++) {
                            byte pixelByte = 0;
                            for (int bit = 0; bit < 8; bit++) {
                                int pxY = y + bit;
                                if (pxY < height && x < width && binaryData[pxY * width + x] == 1) {
                                    pixelByte |= (1 << (7 - bit));
                                }
                            }
                            buffer[bufferPos++] = pixelByte;
                        }
                        
                        // Right half command
                        byte[] rightCmd = {0x1B, 0x24, (byte)250, 0x00, 0x1B, 0x2A, 0x01, (byte)250, 0};
                        
                        if (bufferPos + rightCmd.length + 250 + 1 > buffer.length) {
                            fos.write(buffer, 0, bufferPos);
                            fos.flush();
                            bufferPos = 0;
                            Thread.sleep(50);
                        }
                        
                        System.arraycopy(rightCmd, 0, buffer, bufferPos, rightCmd.length);
                        bufferPos += rightCmd.length;
                        
                        // Process right half (250-499)
                        for (int x = 250; x < 500 && x < width; x++) {
                            byte pixelByte = 0;
                            for (int bit = 0; bit < 8; bit++) {
                                int pxY = y + bit;
                                if (pxY < height && binaryData[pxY * width + x] == 1) {
                                    pixelByte |= (1 << (7 - bit));
                                }
                            }
                            buffer[bufferPos++] = pixelByte;
                        }
                        
                        buffer[bufferPos++] = 0x0A; // Line feed
                    }
                    
                    // Send remaining data
                    if (bufferPos > 0) {
                        fos.write(buffer, 0, bufferPos);
                        fos.flush();
                    }
                    
                    // Final commands
                    Thread.sleep(60);
                    fos.write(new byte[]{0x1B, 0x33, 0x18, 0x1B, 0x40});
                    fos.flush();
                    
                    result.success("Image printed successfully from bytes!");
                    
                } catch (IOException e) {
                    result.error("PRINT_ERROR", "Print failed: " + e.getMessage(), null);
                }
                
            } catch (Exception e) {
                result.error("ERROR", "Failed to print: " + e.getMessage(), null);
            }
        }).start();
    }

    // ✅ แก้ไข method printPdfAsImage ให้เหมือน printImageFromBytes เป๊ะๆ
    private void printPdfAsImage(byte[] pdfData, String portPath, int dpi, MethodChannel.Result result) {
        new Thread(() -> {
            try {
                // 1. บันทึก PDF ลงไฟล์ชั่วคราว
                File tempPdfFile = new File(getCacheDir(), "temp_receipt.pdf");
                try (FileOutputStream fos = new FileOutputStream(tempPdfFile)) {
                    fos.write(pdfData);
                    fos.flush();
                }

                // 2. เปิด PDF ด้วย PdfRenderer
                ParcelFileDescriptor parcelFileDescriptor = ParcelFileDescriptor.open(
                    tempPdfFile, ParcelFileDescriptor.MODE_READ_ONLY);
                PdfRenderer pdfRenderer = new PdfRenderer(parcelFileDescriptor);

                if (pdfRenderer.getPageCount() == 0) {
                    result.error("PDF_ERROR", "PDF has no pages", null);
                    return;
                }

                // 3. แปลงหน้าแรกเป็น Bitmap
                PdfRenderer.Page page = pdfRenderer.openPage(0);
                
                // แปลง PDF เป็น Bitmap ตามขนาดจริง
                float scale = dpi / 72f; // PDF default is 72 DPI
                int originalWidth = (int) (page.getWidth() * scale);
                int originalHeight = (int) (page.getHeight() * scale);

                Bitmap originalBitmap = Bitmap.createBitmap(originalWidth, originalHeight, Bitmap.Config.ARGB_8888);
                originalBitmap.eraseColor(Color.WHITE); // พื้นหลังสีขาว
                
                // Render PDF page ลง Bitmap
                page.render(originalBitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT);
                
                // ปิด PDF resources
                page.close();
                pdfRenderer.close();
                parcelFileDescriptor.close();
                tempPdfFile.delete(); // ลบไฟล์ชั่วคราว

                Log.d(TAG, "PDF converted to bitmap: " + originalWidth + "x" + originalHeight);

                // ✅ 4. Resize เหมือน printImageFromBytes เป๊ะๆ (ส่วนนี้คือกุญแจสำคัญ!)
                float aspectRatio = (float) originalBitmap.getWidth() / originalBitmap.getHeight();
                int targetWidth = 500;
                int targetHeight = (int) (targetWidth / aspectRatio * 0.4f);
                
                Bitmap resizedBitmap = Bitmap.createScaledBitmap(
                    originalBitmap, targetWidth, targetHeight, true);
                originalBitmap.recycle();

                Log.d(TAG, "Resized bitmap to: " + targetWidth + "x" + targetHeight);

                // ✅ 5. Convert to binary data เหมือน printImageFromBytes เป๊ะๆ
                int width = resizedBitmap.getWidth();
                int height = resizedBitmap.getHeight();
                byte[] binaryData = new byte[width * height];
                
                int[] pixels = new int[width * height];
                resizedBitmap.getPixels(pixels, 0, width, 0, 0, width, height);
                
                for (int i = 0; i < pixels.length; i++) {
                    int luminance = (Color.red(pixels[i]) + Color.green(pixels[i]) + Color.blue(pixels[i])) / 3;
                    binaryData[i] = (byte) (luminance < 128 ? 1 : 0);
                }
                
                resizedBitmap.recycle();

                // ✅ 6. Print to serial port เหมือน printImageFromBytes เป๊ะๆ
                try (FileOutputStream fos = new FileOutputStream(portPath)) {
                    // Initialize printer
                    fos.write(new byte[]{0x1B, 0x40, 0x1B, 0x33, 0x00});
                    fos.flush();
                    Thread.sleep(250);

                    // Process and send data
                    byte[] buffer = new byte[512];
                    int bufferPos = 0;
                    
                    for (int y = 0; y < height; y += 8) {
                        // Left half command
                        byte[] leftCmd = {0x1B, 0x24, 0x00, 0x00, 0x1B, 0x2A, 0x01, (byte)250, 0};
                        
                        if (bufferPos + leftCmd.length + 250 > buffer.length) {
                            fos.write(buffer, 0, bufferPos);
                            fos.flush();
                            bufferPos = 0;
                            Thread.sleep(50);
                        }
                        
                        System.arraycopy(leftCmd, 0, buffer, bufferPos, leftCmd.length);
                        bufferPos += leftCmd.length;
                        
                        // Process left half (0-249)
                        for (int x = 0; x < 250; x++) {
                            byte pixelByte = 0;
                            for (int bit = 0; bit < 8; bit++) {
                                int pxY = y + bit;
                                if (pxY < height && x < width && binaryData[pxY * width + x] == 1) {
                                    pixelByte |= (1 << (7 - bit));
                                }
                            }
                            buffer[bufferPos++] = pixelByte;
                        }
                        
                        // Right half command
                        byte[] rightCmd = {0x1B, 0x24, (byte)250, 0x00, 0x1B, 0x2A, 0x01, (byte)250, 0};
                        
                        if (bufferPos + rightCmd.length + 250 + 1 > buffer.length) {
                            fos.write(buffer, 0, bufferPos);
                            fos.flush();
                            bufferPos = 0;
                            Thread.sleep(50);
                        }
                        
                        System.arraycopy(rightCmd, 0, buffer, bufferPos, rightCmd.length);
                        bufferPos += rightCmd.length;
                        
                        // Process right half (250-499)
                        for (int x = 250; x < 500 && x < width; x++) {
                            byte pixelByte = 0;
                            for (int bit = 0; bit < 8; bit++) {
                                int pxY = y + bit;
                                if (pxY < height && binaryData[pxY * width + x] == 1) {
                                    pixelByte |= (1 << (7 - bit));
                                }
                            }
                            buffer[bufferPos++] = pixelByte;
                        }
                        
                        buffer[bufferPos++] = 0x0A; // Line feed
                    }
                    
                    // Send remaining data
                    if (bufferPos > 0) {
                        fos.write(buffer, 0, bufferPos);
                        fos.flush();
                    }
                    
                    // Final commands
                    Thread.sleep(60);
                    fos.write(new byte[]{0x1B, 0x33, 0x18, 0x1B, 0x40});
                    fos.flush();
                    
                    result.success("PDF printed successfully as image!");
                    
                } catch (IOException e) {
                    result.error("PRINT_ERROR", "Print failed: " + e.getMessage(), null);
                }

            } catch (Exception e) {
                Log.e(TAG, "Error printing PDF as image: " + e.getMessage());
                result.error("PDF_PRINT_ERROR", "Failed to print PDF: " + e.getMessage(), null);
            }
        }).start();
    }
private void printPdfAsImageAutoResize(byte[] pdfData, String portPath, int dpi, MethodChannel.Result result) {
    new Thread(() -> {
        try {
            // 1-3. เหมือนเดิม (สร้าง PDF, render bitmap)
            File tempPdfFile = new File(getCacheDir(), "temp_receipt.pdf");
            try (FileOutputStream fos = new FileOutputStream(tempPdfFile)) {
                fos.write(pdfData);
                fos.flush();
            }

            ParcelFileDescriptor parcelFileDescriptor = ParcelFileDescriptor.open(
                tempPdfFile, ParcelFileDescriptor.MODE_READ_ONLY);
            PdfRenderer pdfRenderer = new PdfRenderer(parcelFileDescriptor);

            if (pdfRenderer.getPageCount() == 0) {
                result.error("PDF_ERROR", "PDF has no pages", null);
                return;
            }

            PdfRenderer.Page page = pdfRenderer.openPage(0);
            
            float scale = dpi / 72f;
            int originalWidth = (int) (page.getWidth() * scale);
            int originalHeight = (int) (page.getHeight() * scale);

            Bitmap originalBitmap = Bitmap.createBitmap(originalWidth, originalHeight, Bitmap.Config.ARGB_8888);
            originalBitmap.eraseColor(Color.WHITE);
            
            page.render(originalBitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT);
            
            page.close();
            pdfRenderer.close();
            parcelFileDescriptor.close();
            tempPdfFile.delete();

            Log.d(TAG, "PDF converted to bitmap: " + originalWidth + "x" + originalHeight);

            // 4. Auto Resize Logic - เหมือนเดิม
            Bitmap finalBitmap;
            int width, height;
            
            if (originalWidth <= 500) {
                finalBitmap = originalBitmap;
                width = originalWidth;
                height = originalHeight;
                Log.d(TAG, "Using original size (Auto): " + width + "x" + height);
            } else {
                float aspectRatio = (float) originalBitmap.getWidth() / originalBitmap.getHeight();
                int targetWidth = 500;
                int targetHeight = (int) (targetWidth / aspectRatio);
                
                finalBitmap = Bitmap.createScaledBitmap(
                    originalBitmap, targetWidth, targetHeight, true);
                originalBitmap.recycle();
                
                width = targetWidth;
                height = targetHeight;
                Log.d(TAG, "Auto-resized to: " + width + "x" + height);
            }

            // 5. Convert to binary data - เหมือนเดิม
            byte[] binaryData = new byte[width * height];
            
            int[] pixels = new int[width * height];
            finalBitmap.getPixels(pixels, 0, width, 0, 0, width, height);
            
            for (int i = 0; i < pixels.length; i++) {
                int luminance = (Color.red(pixels[i]) + Color.green(pixels[i]) + Color.blue(pixels[i])) / 3;
                binaryData[i] = (byte) (luminance < 128 ? 1 : 0);
            }
            
            finalBitmap.recycle();

            // ✅ 6. แก้ไข Print Logic ให้จัดกึ่งกลางถูกต้อง
            try (FileOutputStream fos = new FileOutputStream(portPath)) {
                // Initialize printer
                fos.write(new byte[]{0x1B, 0x40, 0x1B, 0x33, 0x00});
                fos.flush();
                Thread.sleep(250);

                byte[] buffer = new byte[512];
                int bufferPos = 0;
                
                for (int y = 0; y < height; y += 8) {
                    
                    if (width <= 500) {
                        // ✅ สำหรับ PDF ทุกขนาด ให้จัดกึ่งกลางใน 500px
                        
                        // คำนวณตำแหน่งเริ่มต้นให้อยู่กึ่งกลาง
                        int totalPrinterWidth = 500; // ความกว้างเต็มของเครื่องพิมพ์
                        int startOffset = (totalPrinterWidth - width) / 2;
                        
                        Log.d(TAG, "Centering: width=" + width + ", offset=" + startOffset);
                        
                        // แบ่งเป็น 2 ส่วน: Left half และ Right half
                        
                        // === LEFT HALF (0-249) ===
                        int leftWidth = Math.min(250 - startOffset, width);
                        if (leftWidth > 0 && startOffset < 250) {
                            int leftOffset = Math.max(0, startOffset);
                            
                            byte[] leftCmd = {0x1B, 0x24, (byte)(leftOffset & 0xFF), (byte)((leftOffset >> 8) & 0xFF), 
                                            0x1B, 0x2A, 0x01, (byte)leftWidth, 0};
                            
                            if (bufferPos + leftCmd.length + leftWidth > buffer.length) {
                                fos.write(buffer, 0, bufferPos);
                                fos.flush();
                                bufferPos = 0;
                                Thread.sleep(50);
                            }
                            
                            System.arraycopy(leftCmd, 0, buffer, bufferPos, leftCmd.length);
                            bufferPos += leftCmd.length;
                            
                            // ส่งข้อมูล pixel สำหรับ left half
                            int sourceStartX = Math.max(0, startOffset < 0 ? -startOffset : 0);
                            for (int i = 0; i < leftWidth; i++) {
                                byte pixelByte = 0;
                                for (int bit = 0; bit < 8; bit++) {
                                    int pxY = y + bit;
                                    int pxX = sourceStartX + i;
                                    if (pxY < height && pxX < width && binaryData[pxY * width + pxX] == 1) {
                                        pixelByte |= (1 << (7 - bit));
                                    }
                                }
                                buffer[bufferPos++] = pixelByte;
                            }
                        }
                        
                        // === RIGHT HALF (250-499) ===
                        int rightStartX = Math.max(0, 250 - startOffset); // ตำแหน่งเริ่มต้นใน source image
                        int rightWidth = Math.min(250, width - rightStartX);
                        
                        if (rightWidth > 0 && rightStartX < width) {
                            byte[] rightCmd = {0x1B, 0x24, (byte)250, 0x00, 
                                             0x1B, 0x2A, 0x01, (byte)rightWidth, 0};
                            
                            if (bufferPos + rightCmd.length + rightWidth + 1 > buffer.length) {
                                fos.write(buffer, 0, bufferPos);
                                fos.flush();
                                bufferPos = 0;
                                Thread.sleep(50);
                            }
                            
                            System.arraycopy(rightCmd, 0, buffer, bufferPos, rightCmd.length);
                            bufferPos += rightCmd.length;
                            
                            // ส่งข้อมูล pixel สำหรับ right half
                            for (int i = 0; i < rightWidth; i++) {
                                byte pixelByte = 0;
                                for (int bit = 0; bit < 8; bit++) {
                                    int pxY = y + bit;
                                    int pxX = rightStartX + i;
                                    if (pxY < height && pxX < width && binaryData[pxY * width + pxX] == 1) {
                                        pixelByte |= (1 << (7 - bit));
                                    }
                                }
                                buffer[bufferPos++] = pixelByte;
                            }
                        }
                        
                        buffer[bufferPos++] = 0x0A; // Line feed
                    }
                }
                
                // Send remaining data
                if (bufferPos > 0) {
                    fos.write(buffer, 0, bufferPos);
                    fos.flush();
                }
                
                // Final commands
                Thread.sleep(60);
                fos.write(new byte[]{0x1B, 0x33, 0x18, 0x1B, 0x40});
                fos.flush();
                
                result.success("PDF printed successfully with auto-resize and centering!");
                
            } catch (IOException e) {
                result.error("PRINT_ERROR", "Print failed: " + e.getMessage(), null);
            }

        } catch (Exception e) {
            Log.e(TAG, "Error printing PDF with auto-resize: " + e.getMessage());
            result.error("PDF_PRINT_ERROR", "Failed to print PDF: " + e.getMessage(), null);
        }
    }).start();
}
}