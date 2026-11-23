// Verifies that QR export/import and effect-chain sending use the MKII patch
// layout: 21 patches, no CAB block, and the active Pro Scene.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_utils/qr_utils.dart';
import 'package:wakelock_plus_platform_interface/messages.g.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import 'package:almighty_amp/bluetooth/devices/NuxConstants.dart';
import 'package:almighty_amp/bluetooth/devices/NuxMighty20Mk2.dart';
import 'package:almighty_amp/bluetooth/devices/NuxMightyPlugPro.dart';
import 'package:almighty_amp/bluetooth/devices/communication/plugProCommunication.dart';

const officialMk2Qr =
    'nux://MightyAmp:FQEAQUFBQUFBQQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAyMjIyMjIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMgBkAAAAAAAAAAAAAAAAAAAAAAUBAgMEBgcIAAAAAAAAAAAAAAAAAAAAAA==';

const _prefixLength = 2; // device QR id + version

int _reverbModelFromQr(String qr) {
  final data = base64Decode(qr.substring(QrUtils.nuxQRPrefix.length));
  return data[_prefixLength + PresetDataIndexPlugPro.Head_iRVB] & 0x3f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((call) async {
      if (call.method == 'getApplicationSupportDirectory' ||
          call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getExternalStorageDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'dev.flutter.pigeon.WakelockPlusApi.toggle',
      'dev.flutter.pigeon.WakelockPlusApi.isEnabled',
    ]) {
      messenger.setMockMessageHandler(channel, (message) async {
        return WakelockPlusApi.codec.encodeMessage(<Object?>[]);
      });
    }
  });

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

  test('MKII QR export leaves the CAB block empty', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final data = base64Decode(
        device.channelToQR(device.selectedNuxIndex).substring(QrUtils.nuxQRPrefix.length));

    int payload(int index) => data[_prefixLength + index];

    expect(payload(PresetDataIndexPlugPro.Head_iCAB), 0);
    expect(payload(PresetDataIndexPlugPro.CAB_Count), 0);
    expect(payload(PresetDataIndexPlugPro.CAB_Para4), 0);
    expect(payload(PresetDataIndexPlugPro.CAB_Para6), 0);
    for (final link in [
      PresetDataIndexPlugPro.LINK1,
      PresetDataIndexPlugPro.LINK2,
      PresetDataIndexPlugPro.LINK3,
      PresetDataIndexPlugPro.LINK4,
      PresetDataIndexPlugPro.LINK5,
      PresetDataIndexPlugPro.LINK6,
      PresetDataIndexPlugPro.LINK7,
      PresetDataIndexPlugPro.LINK8,
      PresetDataIndexPlugPro.LINK9,
    ]) {
      expect(payload(link), isNot(PresetDataIndexPlugPro.Head_iCAB));
    }
  });

  test('MKII slot order replaces CAB with 0 but keeps Wah', () {
    final mk2 = NuxMighty20Mk2(NuxDeviceControl.instance());
    final plugPro = NuxMightyPlugPro(NuxDeviceControl.instance());

    // First byte is the chain length; the CAB slot (default position 5) is 0.
    expect((mk2.communication as PlugProCommunication).buildSlotOrder(),
        [9, 5, 1, 6, 2, 3, 0, 4, 8, 7]);

    // Plug Pro keeps its real CAB id somewhere in the chain.
    expect((plugPro.communication as PlugProCommunication).buildSlotOrder(),
        contains(PresetDataIndexPlugPro.Head_iCAB));
  });

  test('official MKII QR keeps the CAB slot empty in the sent chain', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final preset = device.presets.first;

    final report = preset.setupPresetFromQRDataReport(officialMk2Qr,
        sendToDevice: false);
    expect(report.isOk, isTrue);

    final order = (device.communication as PlugProCommunication).buildSlotOrder();
    expect(order, [9, 5, 1, 2, 3, 4, 6, 7, 8, 0]);
    expect(order.sublist(1),
        isNot(contains(PresetDataIndexPlugPro.Head_iCAB)));
  });
}
