// Verifies the Mighty 20 MKII modulation model set and order.
// This must not affect other devices (they keep PlugProPreset's modulation list).

import 'package:flutter_test/flutter_test.dart';
import 'package:almighty_amp/bluetooth/devices/NuxConstants.dart';
import 'package:almighty_amp/bluetooth/devices/effects/plug_pro/Modulation.dart';
import 'package:almighty_amp/bluetooth/devices/presets/Mighty20Mk2Preset.dart';
import 'package:almighty_amp/bluetooth/devices/value_formatters/SwitchFormatters.dart';

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

  test('MKII U-Vibe moves the real mode control to the Mode switch', () {
    final vibe = Mighty20Mk2Preset.createModulationList()[8];
    final handles = vibe.parameters.map((p) => p.handle).toList();

    expect(handles, contains('speed'));
    expect(handles, contains('volume'));
    expect(handles, contains('mode'));
    expect(handles, isNot(contains('intensity')));

    String nameFor(String handle) =>
        vibe.parameters.firstWhere((p) => p.handle == handle).name;
    expect(nameFor('speed'), 'Rate');
    expect(nameFor('volume'), 'Depth');
    expect(nameFor('mode'), 'Mode');

    final mode = vibe.parameters.firstWhere((p) => p.handle == 'mode');
    expect(mode.devicePresetIndex, PresetDataIndexPlugPro.MOD_Para3);
    expect(mode.midiCC, MidiCCValuesPro.MOD_Para3);
    expect(mode.formatter, isA<VibeModeFormatterPro>());

    mode.value = 0;
    expect(mode.midiValue, 0); // Chorus
    mode.value = 1;
    expect(mode.midiValue, 1); // Vibrato

    // The unused MOD_Para4 is no longer exposed.
    expect(
        vibe.parameters
            .any((p) => p.devicePresetIndex == PresetDataIndexPlugPro.MOD_Para4),
        isFalse);
  });

  test('Plug Pro U-Vibe keeps Intensity and its original Mode control', () {
    final vibe = VibePro();
    final handles = vibe.parameters.map((p) => p.handle).toList();

    expect(handles, contains('intensity'));

    String nameFor(String handle) =>
        vibe.parameters.firstWhere((p) => p.handle == handle).name;
    expect(nameFor('speed'), 'Speed');
    expect(nameFor('volume'), 'Volume');

    expect(
        vibe.parameters
            .firstWhere((p) => p.handle == 'intensity')
            .devicePresetIndex,
        PresetDataIndexPlugPro.MOD_Para3);
    expect(
        vibe.parameters
            .firstWhere((p) => p.handle == 'mode')
            .devicePresetIndex,
        PresetDataIndexPlugPro.MOD_Para4);
  });
}
