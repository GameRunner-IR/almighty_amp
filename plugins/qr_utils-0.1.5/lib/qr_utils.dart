import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:zxing2/qrcode.dart';

enum PresetQRError { Ok, UnsupportedFormat, WrongDevice, WrongFWVersion }

class QrUtils {
  static const nuxQRPrefix = "nux://MightyAmp:";
  static const QRMessages = [
    "Imported Successfully",
    "Error! Unsupported Format!",
    "Error! This preset is for a different device. It can only be imported on the matching device.",
    "Error! This preset is for different firmware version!"
  ];
  static const MethodChannel _channel =
      const MethodChannel('com.aeologic.adhoc.qr_utils');

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // Returns Future<String> after scanning QR code
  static Future<String?> get scanQR async {
    if (_isDesktop) return null;
    final String? qrContent = await _channel.invokeMethod('scanQR');
    return qrContent;
  }

  static Future<String?> scanImageFromData(List<int> data) async {
    if (_isDesktop) {
      return _decodeQrFromBytes(Uint8List.fromList(data));
    }
    final String? qrContent =
        await _channel.invokeMethod('scanImage', {"data": data});
    return qrContent;
  }

  static Future<String?> scanImage() async {
    if (_isDesktop) return null;
    final String? qrContent = await _channel.invokeMethod('scanImage');
    return qrContent;
  }

  // Returns Future<Image> after generating QR Image
  static Future<Image> generateQR(String content) async {
    final Uint8List uInt8list = await generateQRByteArray(content);
    return imageFromUInt8List(uInt8list);
  }

  // Returns Future<Uint8List> after generating QR Image
  static Future<Uint8List> generateQRByteArray(String content) async {
    if (_isDesktop) {
      return _generateQrPng(content);
    }
    final Uint8List uInt8list =
        await _channel.invokeMethod('generateQR', {"content": content});
    return uInt8list;
  }

  static Uint8List _generateQrPng(String content) {
    final qrCode = QrCode.fromData(
        data: content, errorCorrectLevel: QrErrorCorrectLevel.H);
    final qrImage = QrImage(qrCode);
    final image = img.Image(qrImage.moduleCount, qrImage.moduleCount);
    image.fill(img.getColor(255, 255, 255));
    final black = img.getColor(0, 0, 0);
    for (var x = 0; x < qrImage.moduleCount; x++) {
      for (var y = 0; y < qrImage.moduleCount; y++) {
        if (qrImage.isDark(y, x)) {
          image.setPixel(x, y, black);
        }
      }
    }
    final scaled = img.copyResize(image,
        width: qrImage.moduleCount * 8,
        height: qrImage.moduleCount * 8,
        interpolation: img.Interpolation.nearest);
    return Uint8List.fromList(img.encodePng(scaled));
  }

  static String? _decodeQrFromBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('[QR] decodeImage returned null, bytes=${bytes.length}');
        return null;
      }
      debugPrint('[QR] decoded image ${decoded.width}x${decoded.height}');

      img.Image processed = img.grayscale(decoded);
      processed = img.adjustColor(processed, contrast: 1.3);

      final candidates = <img.Image>[processed];
      final maxDim = processed.width > processed.height ? processed.width : processed.height;
      if (maxDim > 1200) {
        final scale = 1200 / maxDim;
        candidates.add(img.copyResize(processed,
            width: (processed.width * scale).round(),
            height: (processed.height * scale).round(),
            interpolation: img.Interpolation.average));
      }

      final hints = DecodeHints();
      hints.put(DecodeHintType.tryHarder);

      for (var ci = 0; ci < candidates.length; ci++) {
        final image = candidates[ci];
        debugPrint('[QR] trying candidate $ci ${image.width}x${image.height}');
        final pixels = Int32List(image.width * image.height);
        var i = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final p = image.getPixel(x, y);
            final r = img.getRed(p);
            final g = img.getGreen(p);
            final b = img.getBlue(p);
            final a = img.getAlpha(p);
            pixels[i++] = (a << 24) | (r << 16) | (g << 8) | b;
          }
        }
        final source = RGBLuminanceSource(image.width, image.height, pixels);
        for (final inverted in [false, true]) {
          final src = inverted ? source.invert() : source;
          for (final binarizerName in ['hybrid', 'global']) {
            final bitmap = BinaryBitmap(binarizerName == 'hybrid'
                ? HybridBinarizer(src)
                : GlobalHistogramBinarizer(src));
            try {
              final result = QRCodeReader().decode(bitmap, hints: hints);
              debugPrint('[QR] decoded via $binarizerName inverted=$inverted: ${result.text.substring(0, result.text.length.clamp(0, 40))}');
              return result.text;
            } catch (e) {
              // debugPrint('[QR] $binarizerName inverted=$inverted: $e');
            }
          }
        }
      }
      debugPrint('[QR] no QR found in image');
      return null;
    } catch (e, st) {
      debugPrint('[QR] decode exception: $e\n$st');
      return null;
    }
  }

  // Returns Image from base64
  static Image imageFromBase64String(String base64String) {
    return Image.memory(base64Decode(base64String));
  }

  // Returns Uint8List from base64
  static Uint8List dataFromBase64String(String base64String) {
    return base64Decode(base64String);
  }

  // Returns String from Uint8List
  static String base64String(Uint8List data) {
    return base64Encode(data);
  }

  // Returns Image from Uint8List
  static Image imageFromUInt8List(Uint8List data) {
    return Image.memory(data);
  }
}
