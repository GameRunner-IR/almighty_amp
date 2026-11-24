// The Mighty 20 MKII Bluetooth EQ is a Volume/Bass/Mid/Treble tone stack.
// Its kSYX_BTSET reply is a hardcoded raw 15 (-10.5 dB), so values are kept
// locally and followed through CC echoes. Plug Pro devices must be unaffected.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import 'package:almighty_amp/bluetooth/devices/NuxConstants.dart';
import 'package:almighty_amp/bluetooth/devices/NuxMighty20Mk2.dart';
import 'package:almighty_amp/bluetooth/devices/NuxMightyPlugPro.dart';
import 'package:almighty_amp/bluetooth/devices/communication/plugProCommunication.dart';
import 'package:almighty_amp/bluetooth/devices/effects/plug_pro/EQ.dart';
import 'package:almighty_amp/platform/simpleSharedPrefs.dart';
import 'package:wakelock_plus_platform_interface/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // A private directory keeps SharedPrefs isolated from the other test files
    // when flutter test runs them concurrently.
    final prefsDir = Directory.systemTemp.createTempSync('mk2_bt_eq_');
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((call) async {
      if (call.method == 'getApplicationSupportDirectory' ||
          call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getExternalStorageDirectory') {
        return prefsDir.path;
      }
      return null;
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'dev.flutter.pigeon.WakelockPlusApi.toggle',
      'dev.flutter.pigeon.WakelockPlusApi.isEnabled',
    ]) {
      messenger.setMockMessageHandler(channel, (message) async {
        return WakelockPlusApi.codec.encodeMessage(<Object?>[]);
      });
    }

    SharedPrefs().remove(SettingsKeys.mk2BluetoothEQ);
    SharedPrefs().remove(SettingsKeys.mk2UsbAudio);
  });

  test('MKII config uses the 4-band Bluetooth EQ', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final eq = device.config.bluetoothEQ;

    expect(eq, isA<EQFourBandBTMk2>());
    expect(eq.parameters.map((p) => p.name).toList(),
        ["Volume", "Bass", "Mid", "Treble"]);
    expect(eq.parameters.map((p) => p.midiCC).toList(), [
      MidiCCValuesPro.AUX_BAND_1,
      MidiCCValuesPro.AUX_BAND_2,
      MidiCCValuesPro.AUX_BAND_3,
      MidiCCValuesPro.AUX_BAND_4,
    ]);
    expect(device.supportsBTEQGroupSave, false);
    expect(device.supportsBTEQReadback, false);
    expect(device.showMatchingCabinetsSetting, false);
    expect(device.showMicrophoneSettings, false);
    expect(device.showUsbCabSimSetting, true);
    // Cab Sim is a global USB setting, not the Plug Pro CAB effect block.
    expect(device.cabinetSupport, false);
    // Hardware factory default is raw 15 (-10.5 dB), not 0 dB.
    for (final param in eq.parameters) {
      expect(param.midiValue, 15);
    }
  });

  test('MKII read-back uses the shared 0-100 scale', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final eq = device.config.bluetoothEQ;

    // Raw bytes captured from the amplifier. 15 really is -10.5 dB on the
    // hardware (confirmed against the official app), not a 0-30 "flat" value.
    eq.setupFromNuxPayload(const [
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      15,
      147,
      247
    ]);
    for (final param in eq.parameters) {
      expect(param.value, closeTo(-10.5, 0.001),
          reason: '${param.name} mirrors the raw hardware value');
    }

    // A value written by the official app must be displayed verbatim.
    eq.setupFromNuxPayload(const [50, 83, 0, 100]);
    expect(eq.parameters[0].value, closeTo(0.0, 0.001));
    expect(eq.parameters[1].value, closeTo(9.9, 0.001));
    expect(eq.parameters[2].value, closeTo(-15.0, 0.001));
    expect(eq.parameters[3].value, closeTo(15.0, 0.001));
  });

  test('MKII writes still use the Plug Pro 0-100 CC scale', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final eq = device.config.bluetoothEQ;

    eq.parameters[1].value = 0; // Bass at 0 dB
    expect(eq.parameters[1].midiValue, 50);
    eq.parameters[1].value = 15; // Bass at +15 dB
    expect(eq.parameters[1].midiValue, 100);
    eq.parameters[1].value = -15; // Bass at -15 dB
    expect(eq.parameters[1].midiValue, 0);
  });

  test('Plug Pro keeps the 10-band Bluetooth EQ and its 0-100 read scale', () {
    final device = NuxMightyPlugPro(NuxDeviceControl.instance());
    final eq = device.config.bluetoothEQ;

    expect(eq, isNot(isA<EQFourBandBTMk2>()));
    expect(eq.parameters.length, 11);
    eq.setupFromNuxPayload(List<int>.filled(14, 15));
    expect(eq.parameters.first.value, closeTo(-10.5, 0.001));
    expect(device.showMatchingCabinetsSetting, true);
    expect(device.showMicrophoneSettings, true);
    expect(device.showUsbCabSimSetting, false);
  });

  test('MKII USB audio settings are restored from local storage', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    expect(device.supportsUSBSettingsReadback, false);

    device
      ..setUsbMode(17)
      ..setUsbRecordingVol(64)
      ..setUsbPlaybackVol(70)
      ..setUsbDryWetVol(80);

    final reopened = NuxMighty20Mk2(NuxDeviceControl.instance());
    expect(reopened.config.routingMode, 17);
    expect(reopened.config.recLevel, 64);
    expect(reopened.config.playbackLevel, 70);
    expect(reopened.config.usbDryWet, 80);

    // Plug Pro must keep using its SYSTEMSET read-back and never write the
    // MKII-specific preference.
    final plugPro = NuxMightyPlugPro(NuxDeviceControl.instance());
    expect(plugPro.supportsUSBSettingsReadback, true);
    plugPro.setUsbMode(2);
    final stored = SharedPrefs().getValue(SettingsKeys.mk2UsbAudio, null);
    expect(stored, isA<Map>());
    expect(stored['routingMode'], 17);
  });

  test('MKII Cab Sim is a persisted USB toggle, not a CAB effect block', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    expect(device.config.mk2CabSim, false);

    device.setUsbCabSim(true);
    expect(device.config.mk2CabSim, true);
    expect(device.cabinetSupport, false);

    final reopened = NuxMighty20Mk2(NuxDeviceControl.instance());
    expect(reopened.config.mk2CabSim, true);

    final stored = SharedPrefs().getValue(SettingsKeys.mk2UsbAudio, null);
    expect(stored, isA<Map>());
    expect(stored['cabSim'], true);

    reopened.setUsbCabSim(false);
    final closed = NuxMighty20Mk2(NuxDeviceControl.instance());
    expect(closed.config.mk2CabSim, false);
  });

  test('MKII Cab Sim SET frame reuses the captured SYSTEMSET fields', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final communication = device.communication as PlugProCommunication;

    // Reply payload captured from the amplifier with Cab Sim enabled.
    // [direction, mic/USB fields..., checksum, 0xF7]
    const reply = [
      2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      50, 50, 0, 54, 127, 44, 0, 227, 247
    ];

    final off = communication.buildMK2CabSimMessage(false, reply);
    expect(off[6], SyxMsg.kSYX_SYSTEMSET);
    expect(off[7], SyxDir.kSYXDIR_SET);
    expect(off[12], 0, reason: 'Cab Sim is reply payload index 5');

    final on = communication.buildMK2CabSimMessage(true, reply);
    expect(on[12], 1);
    // All other captured fields are preserved verbatim.
    expect(on[23], 50); // recording level
    expect(on[24], 50); // playback level
    expect(on[26], 54); // dry/wet
    expect(on[30], 0x80);
    expect(on.last, MidiMessageValues.sysExEnd);
  });

  test('MKII ignores a short SYSTEMSET ACK instead of throwing', () {
    final device = NuxMighty20Mk2(NuxDeviceControl.instance());
    final communication = device.communication as PlugProCommunication;

    // 11-byte payload: direction + fields, but no mic volume/active channels.
    // The amplifier can send this as an ACK after a SET.
    final shortAck = <int>[
      0x80,
      0x80,
      MidiMessageValues.sysExStart,
      0x43,
      0x58,
      SysexPrivacy.kSYSEX_PRIVATE,
      SyxMsg.kSYX_SYSTEMSET,
      SyxDir.kSYXDIR_REQ,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      MidiMessageValues.sysExEnd,
    ];

    expect(() => communication.onDataReceive(shortAck), returnsNormally);
    // No Cab Sim readback was parsed from the truncated frame.
    expect(device.config.mk2CabSim, false);
  });
}
