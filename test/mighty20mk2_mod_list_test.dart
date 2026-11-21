// Verifies the Mighty 20 MKII modulation model set and order.
// This must not affect other devices (they keep PlugProPreset's modulation list).

import 'package:flutter_test/flutter_test.dart';
import 'package:mighty_plug_manager/bluetooth/devices/effects/plug_pro/Modulation.dart';
import 'package:mighty_plug_manager/bluetooth/devices/presets/Mighty20Mk2Preset.dart';

void main() {
  test('MKII modulation list has the correct models in order', () {
    final mods = Mighty20Mk2Preset.createModulationList();

    expect(mods.map((m) => m.name).toList(), [
      'CE-1',
      'CE-2',
      'ST Chorus',
      'Vibrato',
      'Flanger',
      'Phase 90',
      'Phase 100',
      'S.C.F.',
      'U-Vibe',
      'Tremolo',
      'SCH-1',
    ]);
  });

  test('MKII modulation list uses the expected model identities', () {
    final mods = Mighty20Mk2Preset.createModulationList();

    expect(mods[0], isA<ModCE1>());
    expect(mods[1], isA<ModCE2>());
    expect(mods[2], isA<STChorusPro>());
    expect(mods[3], isA<Vibrato>());
    expect(mods[4], isA<FlangerPro>());
    expect(mods[5], isA<Phase90>());
    expect(mods[6], isA<Phase100>());
    expect(mods[7], isA<SCFPro>());
    expect(mods[8], isA<VibePro>());
    expect(mods[9], isA<TremoloPro>());
    expect(mods[10], isA<SCH1Pro>());
    expect(mods.length, 11);
  });

  test('MKII modulation list uses MKII hardware model IDs (nuxIndex)', () {
    final mods = Mighty20Mk2Preset.createModulationList();

    // MKII modulation IDs are sequential 1..11 in the device order, unlike the
    // Plug Pro numbering (which skips Detune/Rotary/MonoOctave IDs).
    expect(mods.map((m) => m.nuxIndex).toList(),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
  });
}
