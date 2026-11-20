// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import '../NuxFXID.dart';
import 'PlugProPreset.dart';

/// Mighty 20 MKII preset.
///
/// Keeps the complete Plug Pro processor order for hardware communication, but
/// exposes only non-cabinet slots to the interactive Effect Chain.
class Mighty20Mk2Preset extends PlugProPreset {
  Mighty20Mk2Preset(
      {required super.device,
      required super.channel,
      required super.channelName});

  List<int> get visibleSlotIndices {
    final slots = <int>[];
    for (int i = 0; i < processorAtSlot.length; i++) {
      if (processorAtSlot[i] != PlugProFXID.cab) slots.add(i);
    }
    return slots;
  }
}
