// Verifies the Mighty 20 MKII delay and reverb model sets and order.
// This must not affect other devices (they keep PlugProPreset's lists).

import 'package:flutter_test/flutter_test.dart';
import 'package:almighty_amp/bluetooth/devices/effects/plug_pro/Delay.dart';
import 'package:almighty_amp/bluetooth/devices/effects/plug_pro/Reverb.dart';
import 'package:almighty_amp/bluetooth/devices/presets/Mighty20Mk2Preset.dart';

void main() {
  test('MKII delay list has the correct models in order', () {
    final delays = Mighty20Mk2Preset.createDelayList();

    expect(delays.map((m) => m.name).toList(), [
      'Analog',
      'Digital Delay',
      'Modulation',
      'Tape Echo',
      'Phi Delay',
    ]);
  });

  test('MKII delay list uses expected identities and MKII hardware IDs', () {
    final delays = Mighty20Mk2Preset.createDelayList();

    expect(delays[0], isA<AnalogDelayV2>());
    expect(delays[1], isA<DigitalDelay>());
    expect(delays[2], isA<ModDelay>());
    expect(delays[3], isA<TapeEcho>());
    expect(delays[4], isA<PhiDelayPro>());
    expect(delays.length, 5);

    // Pan Delay removed; Phi Delay becomes 5th with MKII hardware ID 5.
    expect(delays.map((m) => m.nuxIndex).toList(), [1, 2, 3, 4, 5]);
  });

  test('MKII reverb list has the correct models in order', () {
    final reverbs = Mighty20Mk2Preset.createReverbList();

    expect(reverbs.map((m) => m.name).toList(), [
      'Room',
      'Hall',
      'Plate',
      'Spring',
      'Damp',
    ]);
  });

  test('MKII reverb list uses expected identities and MKII hardware IDs', () {
    final reverbs = Mighty20Mk2Preset.createReverbList();

    expect(reverbs[0], isA<RoomReverb>());
    expect(reverbs[1], isA<HallReverb>());
    expect(reverbs[2], isA<PlateReverb>());
    expect(reverbs[3], isA<SpringReverb>());
    expect(reverbs[4], isA<DampReverbPro>());
    expect(reverbs.length, 5);

    // Shimmer removed; Damp becomes 5th with MKII hardware ID 5.
    expect(reverbs.map((m) => m.nuxIndex).toList(), [1, 2, 3, 4, 5]);
  });
}
