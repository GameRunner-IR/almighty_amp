// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import '../NuxFXID.dart';
import '../effects/Processor.dart';
import '../effects/plug_pro/Amps.dart';
import 'PlugProPreset.dart';

/// Mighty 20 MKII preset.
///
/// Keeps the complete Plug Pro processor order for hardware communication, but
/// exposes only non-cabinet slots to the interactive Effect Chain.
///
/// The MKII does not have every amp of the Plug Pro model. Amps that only exist
/// on the Plug Pro (and Space) are removed from the amplifier list so they can't
/// be selected on this device. They are the last entries of the Plug Pro list,
/// so the indices of the remaining amps are unchanged.
class Mighty20Mk2Preset extends PlugProPreset {
  Mighty20Mk2Preset(
      {required super.device,
      required super.channel,
      required super.channelName}) {
    amplifierList.removeWhere((amp) => !isAmpAvailable(amp));
  }

  /// Amps that the Mighty 20 MKII does not provide.
  static bool isAmpAvailable(Amplifier amp) {
    return amp is! AGL && amp is! MLD && amp is! OptimaAir && amp is! Stageman;
  }

  List<int> get visibleSlotIndices {
    final slots = <int>[];
    for (int i = 0; i < processorAtSlot.length; i++) {
      if (processorAtSlot[i] != PlugProFXID.cab) slots.add(i);
    }
    return slots;
  }
}
