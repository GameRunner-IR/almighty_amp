// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import 'NuxMightyPlugPro.dart';
import 'presets/Mighty20Mk2Preset.dart';

/// A Mighty 20 MKII patch: one physical preset and one Pro Scene inside it.
///
/// The amplifier exposes 21 patch slots, addressed over MIDI by a single
/// Program Change number: `preset * 3 + scene`.
class Mk2Patch {
  /// Number of Pro Scenes stored inside every physical preset.
  static const scenesPerPreset = 3;

  /// Zero based preset index (0-6).
  final int preset;

  /// Zero based scene index (0-2).
  final int scene;

  const Mk2Patch(this.preset, this.scene);

  /// Decodes a Program Change number into a patch.
  factory Mk2Patch.fromProgramNumber(int programNumber) {
    return Mk2Patch(
        programNumber ~/ scenesPerPreset, programNumber % scenesPerPreset);
  }

  /// Program Change number that recalls this patch.
  int get programNumber => preset * scenesPerPreset + scene;

  /// Recalling a physical preset always returns to Pro Scene 1.
  Mk2Patch withPreset(int newPreset) => Mk2Patch(newPreset, 0);

  /// Changing the scene keeps the physical preset selected.
  Mk2Patch withScene(int newScene) => Mk2Patch(preset, newScene);

  @override
  bool operator ==(Object other) =>
      other is Mk2Patch && other.preset == preset && other.scene == scene;

  @override
  int get hashCode => Object.hash(preset, scene);

  @override
  String toString() => 'Mk2Patch(preset: $preset, scene: $scene)';
}

/// Experimental alias for NUX Mighty 20 MKII (BLE name: NUX NGA-20).
///
/// The MKII is currently treated as a Mighty Plug Pro at the application level:
/// same communication implementation, preset model, effect definitions, UI and
/// capabilities. Only the BLE identity and display name differ. Hardware
/// limitations (if any) are to be discovered through testing on the device.
///
/// On top of the Plug Pro model, the MKII exposes 21 patches: 7 physical
/// presets, each with 3 Pro Scenes. A patch is recalled with a single MIDI
/// Program Change whose number is `preset * 3 + scene`.
class NuxMighty20Mk2 extends NuxMightyPlugPro {
  /// Number of Pro Scenes stored inside every physical preset.
  static const proScenesPerPreset = Mk2Patch.scenesPerPreset;

  Mk2Patch _patch = const Mk2Patch(0, 0);

  NuxMighty20Mk2(super.devControl) {
    // MKII has 21 patch slots (7 presets * 3 Pro Scenes).
    presets.clear();
    channelNames.clear();
    for (int i = 0; i < channelsCount; i++) {
      channelNames.add("${i + 1}");
    }
    for (int i = 0; i < patchesCount; i++) {
      final patch = Mk2Patch.fromProgramNumber(i);
      presets.add(Mighty20Mk2Preset(
          device: this, channel: i, channelName: "${patch.preset + 1}"));
    }
  }

  @override
  String get productName => "NUX Mighty 20 MKII";
  @override
  String get productNameShort => "Mighty 20 MKII";
  @override
  String get productStringId => "mighty_20_mk2";
  @override
  String get presetClass => productStringId;
  @override
  String get productIconLabel => "20 MKII";
  @override
  List<String> get productBLENames => ["NUX NGA-20"];

  @override
  bool get cabinetSupport => false;

  @override
  bool get hackableIRs => false;

  @override
  int get cabinetSlotIndex => 0;

  @override
  int get proScenesCount => proScenesPerPreset;

  @override
  int get patchesCount => channelsCount * proScenesPerPreset;

  @override
  int get selectedProScene => _patch.scene;

  /// MKII patch addressing: preset 0-6 and scene 0-2 are sent as a single
  /// Program Change number 0-20. This is also the index into [presets].
  @override
  int get selectedProgramNumber => _patch.programNumber;

  @override
  int get selectedNuxIndex => selectedProgramNumber;

  @override
  void setSelectedChannel(int chan,
      {required bool notifyBT,
      required bool sendFullPreset,
      required bool notifyUI}) {
    var patch = _patch;

    // The amplifier may report its current patch as a program number
    // (preset * 3 + scene) where a preset index is expected.
    if (chan >= channelsCount && chan < channelsCount * proScenesPerPreset) {
      patch = Mk2Patch.fromProgramNumber(chan);
    } else if (chan < channelsCount && chan != selectedChannelP) {
      // Recalling a physical preset always returns to Pro Scene 1.
      patch = patch.withPreset(chan);
    }

    _patch = patch;
    super.setSelectedChannel(patch.preset,
        notifyBT: notifyBT, sendFullPreset: sendFullPreset, notifyUI: notifyUI);
  }

  @override
  void setSelectedProScene(int scene,
      {bool notifyBT = true, bool notifyUI = true}) {
    if (scene < 0 || scene >= proScenesPerPreset) return;
    if (_patch.scene == scene) return;

    // Changing the Pro Scene keeps the selected physical preset.
    _patch = _patch.withScene(scene);
    deviceControl.clearPresetData();
    if (notifyBT) {
      deviceControl.changeDeviceChannel(selectedProgramNumber);
    }
    // Apply the cached Nux data for this patch slot (preset*3 + scene).
    getPreset(selectedNuxIndex).setupPresetFromNuxData();
    if (deviceControl.isConnected) sendAmpLevel();
    if (notifyUI) deviceControl.forceNotifyListeners();
  }

  @override
  void handleProgramChange(int programNumber) {
    if (programNumber < 0 ||
        programNumber >= channelsCount * proScenesPerPreset) return;

    final patch = Mk2Patch.fromProgramNumber(programNumber);
    handleChannelChange(patch.preset);
    // handleChannelChange selects scene 1 when the physical preset changes;
    // restore the actual patch carried by the program change and load its data.
    _patch = patch;
    selectedPatch.setupPresetFromNuxData();
    if (deviceControl.isConnected) sendAmpLevel();
    deviceControl.forceNotifyListeners();
  }

  @override
  Mighty20Mk2Preset getCustomPreset(int channel) {
    return Mighty20Mk2Preset(device: this, channel: channel, channelName: "");
  }
}
