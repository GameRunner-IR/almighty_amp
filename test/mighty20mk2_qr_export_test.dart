// Verifies that QR export from the editor uses the active MKII patch.
//
// On the Mighty 20 MKII, [selectedChannel] is the physical preset (0-6) while
// [selectedNuxIndex] is the patch (preset * 3 + scene). QR data is stored per
// patch, so exporting with selectedChannel silently returns the wrong scene.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_utils/qr_utils.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import 'package:almighty_amp/bluetooth/devices/NuxConstants.dart';
import 'package:almighty_amp/bluetooth/devices/NuxMighty20Mk2.dart';

int _reverbModelFromQr(String qr) {
  final data = base64Decode(qr.substring(QrUtils.nuxQRPrefix.length));
  return data[2 + PresetDataIndexPlugPro.Head_iRVB] & 0x3f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MKII QR export uses the active patch, not the physical channel', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final reverbSlot = device.getSlotByEffectKeyName('reverb')!;

    // Give the two patches of the same physical preset different reverb models.
    device.presets[0].setSelectedEffectForSlot(reverbSlot, 3, false); // Spring
    device.presets[1].setSelectedEffectForSlot(reverbSlot, 0, false); // Room

    // Scene 2 of physical preset 1.
    device.setSelectedProScene(1, notifyBT: false, notifyUI: false);

    expect(device.selectedChannel, 0);
    expect(device.selectedNuxIndex, 1);
    expect(device.selectedPatch, same(device.presets[1]));

    final activePatchQr = device.channelToQR(device.selectedNuxIndex);
    final physicalChannelQr = device.channelToQR(device.selectedChannel);

    expect(_reverbModelFromQr(activePatchQr), 1);
    expect(_reverbModelFromQr(physicalChannelQr), 4);
  });
}
