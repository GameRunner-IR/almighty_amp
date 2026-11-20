// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import 'NuxMightyPlugPro.dart';
import 'presets/Mighty20Mk2Preset.dart';

/// Experimental alias for NUX Mighty 20 MKII (BLE name: NUX NGA-20).
///
/// The MKII is currently treated as a Mighty Plug Pro at the application level:
/// same communication implementation, preset model, effect definitions, UI and
/// capabilities. Only the BLE identity and display name differ. Hardware
/// limitations (if any) are to be discovered through testing on the device.
class NuxMighty20Mk2 extends NuxMightyPlugPro {
  NuxMighty20Mk2(super.devControl) {
    for (int i = 0; i < presets.length; i++) {
      presets[i] = Mighty20Mk2Preset(
          device: this, channel: i, channelName: channelNames[i]);
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
  Mighty20Mk2Preset getCustomPreset(int channel) {
    return Mighty20Mk2Preset(device: this, channel: channel, channelName: "");
  }
}
