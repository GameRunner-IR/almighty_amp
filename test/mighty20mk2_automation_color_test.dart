// Jam-track automation colours must use the physical preset index, not the
// MKII patch index stored in saved presets (0-20).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almighty_amp/audio/models/trackAutomation.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import 'package:almighty_amp/platform/presetsStorage.dart';
import 'package:wakelock_plus_platform_interface/messages.g.dart';

AutomationEvent _eventWithPreset(Map<String, dynamic> preset) {
  PresetsStorage().presetsData = [
    {'name': 'Test', 'presets': [preset]}
  ];
  final event = AutomationEvent(
      eventTime: Duration.zero, type: AutomationEventType.preset);
  event.setPresetUuid(preset['uuid']);
  return event;
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

  test('MKII patch index is mapped to the physical channel', () {
    NuxDeviceControl.instance(); // registers all device instances

    final event = _eventWithPreset({
      'uuid': 'mk2-preset',
      'name': 'Scene 3',
      'product_id': 'mighty_20_mk2',
      'channel': 12, // preset 4 (zero based), scene 3
    });

    expect(event.channel, 4);
  });

  test('non-scene devices keep their saved channel', () {
    NuxDeviceControl.instance();

    final event = _eventWithPreset({
      'uuid': 'plug-pro-preset',
      'name': 'Preset 6',
      'product_id': 'mighty_plug_pro',
      'channel': 5,
    });

    expect(event.channel, 5);
  });
}
