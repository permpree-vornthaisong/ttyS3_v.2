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

                // เพิ่ม case ใหม่นี้
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
                Thread.sleep(1000); // Wait 1 second after app start
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

    // เพิ่ม method ใหม่นี้
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

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }
}
