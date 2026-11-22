// Verifies that a Plug Pro QR imported into the Mighty 20 MKII is normalized
// to a 0 dB patch level, while a native MKII QR keeps its own patch level.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_utils/qr_utils.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import 'package:almighty_amp/bluetooth/devices/NuxConstants.dart';
import 'package:almighty_amp/bluetooth/devices/NuxMighty20Mk2.dart';

const plugProQr =
    'nux://MightyAmp:DwEAAQkMAwFJAgIkAAAAAABkQAAAAAxXWAAAAAAjJSFXUC8AAAAyADIyMjIyMjIyMgAAR0oAAAALGQBSAAAARUsPAAAAAAAAQEU8OgAAAAAVMFkAAAAAAAAAAAUBAgMJBAcIBgAAAAAAAAAAAAAAAAAAAA==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only Plug Pro QR conversion normalizes MKII patch level to 0 dB', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final preset = device.presets.first;

    // Source QR has MASTER = 0 (-12 dB). Conversion must force 50 (0 dB).
    final convertedReport =
        preset.setupPresetFromQRDataReport(plugProQr, sendToDevice: false);
    expect(convertedReport.isOk, isTrue);
    expect(preset.volume, 0.0);

    // A native MKII QR with the same MASTER value must stay at -12 dB.
    final source =
        base64Decode(plugProQr.substring(QrUtils.nuxQRPrefix.length));
    final payload = List<int>.from(source.sublist(2));
    payload[PresetDataIndexPlugPro.MASTER] = 0;
    final mk2Qr = QrUtils.nuxQRPrefix +
        base64Encode(<int>[21, 1, ...payload]);

    final nativeReport =
        preset.setupPresetFromQRDataReport(mk2Qr, sendToDevice: false);
    expect(nativeReport.isOk, isTrue);
    expect(preset.volume, -12.0);
  });
}
