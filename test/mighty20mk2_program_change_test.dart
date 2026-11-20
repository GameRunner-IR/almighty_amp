// Verifies Mighty 20 MKII patch (7 presets x 3 Pro Scenes = 21 patches)
// Program Change addressing, selection transitions and the exact outgoing
// BLE-MIDI packet.

import 'package:flutter_test/flutter_test.dart';
import 'package:mighty_plug_manager/bluetooth/devices/NuxMighty20Mk2.dart';
import 'package:mighty_plug_manager/bluetooth/devices/communication/communication.dart';

void main() {
  // Physical preset -> program numbers of Pro Scenes 1, 2 and 3.
  const expected = <int, List<int>>{
    0: [0, 1, 2],
    1: [3, 4, 5],
    2: [6, 7, 8],
    3: [9, 10, 11],
    4: [12, 13, 14],
    5: [15, 16, 17],
    6: [18, 19, 20],
  };

  test('MKII exposes 21 patches', () {
    expect(NuxMighty20Mk2.proScenesPerPreset, 3);
    expect(Mk2Patch.scenesPerPreset, 3);
  });

  test('program number mapping covers all 21 patches', () {
    for (final entry in expected.entries) {
      for (int scene = 0; scene < Mk2Patch.scenesPerPreset; scene++) {
        expect(
          Mk2Patch(entry.key, scene).programNumber,
          entry.value[scene],
          reason: 'preset ${entry.key + 1} / scene ${scene + 1}',
        );
        expect(
          Mk2Patch.fromProgramNumber(entry.value[scene]),
          Mk2Patch(entry.key, scene),
          reason: 'decoding program number ${entry.value[scene]}',
        );
      }
    }
  });

  test('selecting a physical preset resets the Pro Scene to 1', () {
    // Preset 2 / Pro Scene 3 -> tap Preset 7.
    final patch = const Mk2Patch(1, 2).withPreset(6);
    expect(patch, const Mk2Patch(6, 0));
    expect(patch.programNumber, 18);
  });

  test('selecting a Pro Scene keeps the physical preset', () {
    final scene2 = const Mk2Patch(6, 0).withScene(1);
    final scene3 = const Mk2Patch(6, 0).withScene(2);
    expect(scene2, const Mk2Patch(6, 1));
    expect(scene3, const Mk2Patch(6, 2));
    expect(scene2.programNumber, 19);
    expect(scene3.programNumber, 20);

    // Switching scenes on any preset keeps that preset.
    for (final preset in expected.keys) {
      for (int scene = 0; scene < Mk2Patch.scenesPerPreset; scene++) {
        expect(const Mk2Patch(0, 0).withPreset(preset).withScene(scene).preset,
            preset);
      }
    }
  });

  test('exact outgoing Program Change packets', () {
    for (final entry in expected.entries) {
      for (int scene = 0; scene < Mk2Patch.scenesPerPreset; scene++) {
        final programNumber = entry.value[scene];
        expect(
          DeviceCommunication.createPCMessage(programNumber),
          [0x80, 0x80, 0xC0, programNumber],
          reason: 'preset ${entry.key + 1} / scene ${scene + 1}',
        );
      }
    }
  });

  test('examples from the specification', () {
    // Preset 7 / Pro Scene 1 and then scenes 2 and 3.
    final preset7 = DeviceCommunication.createPCMessage(
        const Mk2Patch(1, 2).withPreset(6).programNumber);
    expect(preset7, [0x80, 0x80, 0xC0, 0x12]);
    expect(
        DeviceCommunication.createPCMessage(const Mk2Patch(6, 1).programNumber),
        [0x80, 0x80, 0xC0, 0x13]);
    expect(
        DeviceCommunication.createPCMessage(const Mk2Patch(6, 2).programNumber),
        [0x80, 0x80, 0xC0, 0x14]);
    // Preset 1 / Pro Scene 1 is the special case with program number 0.
    expect(DeviceCommunication.createPCMessage(0), [0x80, 0x80, 0xC0, 0x00]);
  });
}
