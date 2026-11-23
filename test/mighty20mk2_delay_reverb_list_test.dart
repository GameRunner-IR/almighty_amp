// Verifies the Mighty 20 MKII delay and reverb model sets and order.
// This must not affect other devices (they keep PlugProPreset's lists).

import 'package:flutter_test/flutter_test.dart';
import 'package:almighty_amp/bluetooth/devices/NuxConstants.dart';
import 'package:almighty_amp/bluetooth/devices/effects/MidiControllerHandles.dart';
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

  test('MKII Analog delay uses Time/Mix/Repeat labels', () {
    final analog = Mighty20Mk2Preset.createDelayList().first;

    String nameFor(String handle) =>
        analog.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        analog.parameters.firstWhere((p) => p.handle == handle).devicePresetIndex;

    expect(nameFor('rate'), 'Time');
    expect(nameFor('intensity'), 'Mix');
    expect(nameFor('echo'), 'Repeat');

    expect(indexFor('rate'), PresetDataIndexPlugPro.DLY_Para1);
    expect(indexFor('intensity'), PresetDataIndexPlugPro.DLY_Para3);
    expect(indexFor('echo'), PresetDataIndexPlugPro.DLY_Para2);
  });

  test('Plug Pro Analog delay labels are untouched', () {
    final analog = AnalogDelayV2();

    String nameFor(String handle) =>
        analog.parameters.firstWhere((p) => p.handle == handle).name;

    expect(nameFor('rate'), 'Rate');
    expect(nameFor('intensity'), 'Intensity');
    expect(nameFor('echo'), 'Echo');
  });

  test('MKII Digital delay swaps Time/Mix controls and renames Feedback',
      () {
    final digital = Mighty20Mk2Preset.createDelayList()[1];

    String nameFor(String handle) =>
        digital.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        digital.parameters
            .firstWhere((p) => p.handle == handle)
            .devicePresetIndex;
    int ccFor(String handle) =>
        digital.parameters.firstWhere((p) => p.handle == handle).midiCC;

    expect(nameFor('level'), 'Mix');
    expect(nameFor('time'), 'Time');
    expect(nameFor('feedback'), 'Repeat');

    // Time now drives the real time control; Mix drives the real mix control.
    expect(indexFor('time'), PresetDataIndexPlugPro.DLY_Para1);
    expect(ccFor('time'), MidiCCValuesPro.DLY_Para1);
    expect(indexFor('level'), PresetDataIndexPlugPro.DLY_Para3);
    expect(ccFor('level'), MidiCCValuesPro.DLY_Para3);
    expect(indexFor('feedback'), PresetDataIndexPlugPro.DLY_Para2);
  });

  test('Plug Pro Digital delay is untouched', () {
    final digital = DigitalDelay();

    String nameFor(String handle) =>
        digital.parameters.firstWhere((p) => p.handle == handle).name;

    expect(nameFor('level'), 'E.Level');
    expect(nameFor('time'), 'Time');
    expect(nameFor('feedback'), 'Feedback');

    expect(
        digital.parameters
            .firstWhere((p) => p.handle == 'level')
            .devicePresetIndex,
        PresetDataIndexPlugPro.DLY_Para1);
    expect(
        digital.parameters
            .firstWhere((p) => p.handle == 'time')
            .devicePresetIndex,
        PresetDataIndexPlugPro.DLY_Para3);
  });

  test('MKII Modulation delay rotates Level/Repeat/Mod controls', () {
    final modDelay = Mighty20Mk2Preset.createDelayList()[2];

    String nameFor(String handle) =>
        modDelay.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        modDelay.parameters
            .firstWhere((p) => p.handle == handle)
            .devicePresetIndex;
    int ccFor(String handle) =>
        modDelay.parameters.firstWhere((p) => p.handle == handle).midiCC;

    expect(nameFor('time'), 'Time');
    expect(nameFor('level'), 'Mix');
    expect(nameFor('repeat'), 'Repeat');
    expect(nameFor('mod'), 'Mod');

    expect(indexFor('time'), PresetDataIndexPlugPro.DLY_Para1);
    expect(indexFor('level'), PresetDataIndexPlugPro.DLY_Para3);
    expect(indexFor('repeat'), PresetDataIndexPlugPro.DLY_Para2);
    expect(indexFor('mod'), PresetDataIndexPlugPro.DLY_Para4);

    expect(ccFor('level'), MidiCCValuesPro.DLY_Para3);
    expect(ccFor('repeat'), MidiCCValuesPro.DLY_Para2);
    expect(ccFor('mod'), MidiCCValuesPro.DLY_Para4);
  });

  test('Plug Pro Modulation delay is untouched', () {
    final modDelay = ModDelay();

    String nameFor(String handle) =>
        modDelay.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        modDelay.parameters
            .firstWhere((p) => p.handle == handle)
            .devicePresetIndex;

    expect(nameFor('level'), 'Level');
    expect(nameFor('repeat'), 'Repeat');
    expect(nameFor('mod'), 'Mod');

    expect(indexFor('level'), PresetDataIndexPlugPro.DLY_Para2);
    expect(indexFor('repeat'), PresetDataIndexPlugPro.DLY_Para4);
    expect(indexFor('mod'), PresetDataIndexPlugPro.DLY_Para3);
  });

  test('MKII Tape Echo swaps capabilities and sets Mix/Repeat names', () {
    final echo = Mighty20Mk2Preset.createDelayList()[3];

    expect(echo.parameters.map((p) => p.name).toList(), [
      'Mix',
      'Time',
      'Repeat',
    ]);
    expect(echo.parameters.map((p) => p.handle).toList(), [
      'level',
      'time',
      'repeat',
    ]);

    int indexFor(String handle) =>
        echo.parameters
            .firstWhere((p) => p.handle == handle)
            .devicePresetIndex;
    int ccFor(String handle) =>
        echo.parameters.firstWhere((p) => p.handle == handle).midiCC;
    ControllerHandleId? controllerFor(String handle) => echo.parameters
        .firstWhere((p) => p.handle == handle)
        .midiControllerHandle
        ?.id;

    expect(indexFor('time'), PresetDataIndexPlugPro.DLY_Para1);
    expect(indexFor('level'), PresetDataIndexPlugPro.DLY_Para3);
    expect(indexFor('repeat'), PresetDataIndexPlugPro.DLY_Para2);
    expect(ccFor('level'), MidiCCValuesPro.DLY_Para3);
    expect(ccFor('repeat'), MidiCCValuesPro.DLY_Para2);
    expect(controllerFor('level'), ControllerHandleId.delayLevel);
    expect(controllerFor('repeat'), ControllerHandleId.delayRepeat);
  });

  test('Plug Pro Tape Echo is untouched', () {
    final echo = TapeEcho();

    expect(echo.parameters.map((p) => p.name).toList(), [
      'Level',
      'Time',
      'Repeat',
    ]);
    expect(
        echo.parameters
            .firstWhere((p) => p.handle == 'level')
            .devicePresetIndex,
        PresetDataIndexPlugPro.DLY_Para2);
    expect(
        echo.parameters
            .firstWhere((p) => p.handle == 'repeat')
            .devicePresetIndex,
        PresetDataIndexPlugPro.DLY_Para3);
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

  test('MKII Room reverb swaps the Level and Tone labels only', () {
    final room = Mighty20Mk2Preset.createReverbList().first;

    String nameFor(String handle) =>
        room.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        room.parameters.firstWhere((p) => p.handle == handle).devicePresetIndex;

    expect(nameFor('tone'), 'Level');
    expect(nameFor('level'), 'Tone');
    expect(nameFor('decay'), 'Decay');

    // The underlying hardware controls must not change.
    expect(indexFor('tone'), PresetDataIndexPlugPro.RVB_Para2);
    expect(indexFor('level'), PresetDataIndexPlugPro.RVB_Para3);
  });

  test('Plug Pro Room reverb labels are untouched', () {
    final room = RoomReverb();

    String nameFor(String handle) =>
        room.parameters.firstWhere((p) => p.handle == handle).name;

    expect(nameFor('tone'), 'Tone');
    expect(nameFor('level'), 'Level');
  });

  test('MKII Hall reverb drops the dead Level and relabels Level/Tone', () {
    final hall = Mighty20Mk2Preset.createReverbList()[1];

    final handles = hall.parameters.map((p) => p.handle).toList();
    expect(handles, isNot(contains('level')));
    expect(handles, contains('decay'));
    expect(handles, contains('predelay'));
    expect(handles, contains('liveliness'));

    String nameFor(String handle) =>
        hall.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        hall.parameters.firstWhere((p) => p.handle == handle).devicePresetIndex;

    expect(nameFor('decay'), 'Decay');
    expect(nameFor('predelay'), 'Level');
    expect(nameFor('liveliness'), 'Tone');

    // Hardware indices are unchanged; only the dead slider was removed.
    expect(indexFor('decay'), PresetDataIndexPlugPro.RVB_Para1);
    expect(indexFor('predelay'), PresetDataIndexPlugPro.RVB_Para2);
    expect(indexFor('liveliness'), PresetDataIndexPlugPro.RVB_Para3);
    expect(
        hall.parameters
            .any((p) => p.devicePresetIndex == PresetDataIndexPlugPro.RVB_Para4),
        isFalse);
  });

  test('Plug Pro Hall reverb is untouched', () {
    final hall = HallReverb();

    String nameFor(String handle) =>
        hall.parameters.firstWhere((p) => p.handle == handle).name;

    expect(nameFor('level'), 'Level');
    expect(nameFor('predelay'), 'Pre Delay');
    expect(nameFor('liveliness'), 'Liveliness');
  });

  test('MKII Damp reverb relabels Mix/Depth to Decay/Level', () {
    final damp = Mighty20Mk2Preset.createReverbList()[4];

    String nameFor(String handle) =>
        damp.parameters.firstWhere((p) => p.handle == handle).name;
    int indexFor(String handle) =>
        damp.parameters.firstWhere((p) => p.handle == handle).devicePresetIndex;

    expect(nameFor('mix'), 'Decay');
    expect(nameFor('depth'), 'Level');

    expect(indexFor('mix'), PresetDataIndexPlugPro.RVB_Para1);
    expect(indexFor('depth'), PresetDataIndexPlugPro.RVB_Para2);

    // MKII hardware ID stays 5 even though Plug Pro's Damp is 6.
    expect(damp.nuxIndex, 5);
  });

  test('Plug Pro Damp reverb is untouched', () {
    final damp = DampReverbPro();

    String nameFor(String handle) =>
        damp.parameters.firstWhere((p) => p.handle == handle).name;

    expect(nameFor('mix'), 'Mix');
    expect(nameFor('depth'), 'Depth');
  });
}
