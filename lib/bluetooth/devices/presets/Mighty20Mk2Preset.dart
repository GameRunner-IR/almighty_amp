// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import 'package:flutter/material.dart';

import '../NuxFXID.dart';
import '../effects/Processor.dart';
import '../effects/plug_pro/Amps.dart';
import '../effects/plug_pro/Delay.dart';
import '../effects/plug_pro/Modulation.dart';
import '../effects/plug_pro/Reverb.dart';
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
///
/// The modulation models and their order also differ from the Plug Pro on the
/// MKII, so the modulation list is replaced with the MKII-specific set/order.
/// Delay and reverb models also differ (some removed, order/IDs adjusted).
/// The hardware model IDs (nuxIndex) on the MKII are sequential in each
/// category's device order, unlike the Plug Pro numbering, so MKII-specific
/// instances are used where needed.
class Mighty20Mk2Preset extends PlugProPreset {
  Mighty20Mk2Preset(
      {required super.device,
      required super.channel,
      required super.channelName}) {
    amplifierList.removeWhere((amp) => !isAmpAvailable(amp));
    modulationList
      ..clear()
      ..addAll(createModulationList());
    delayList
      ..clear()
      ..addAll(createDelayList());
    reverbList
      ..clear()
      ..addAll(createReverbList());
  }

  /// Amps that the Mighty 20 MKII does not provide.
  static bool isAmpAvailable(Amplifier amp) {
    return amp is! AGL && amp is! MLD && amp is! OptimaAir && amp is! Stageman;
  }

  /// Modulation models available on the Mighty 20 MKII, in the correct order,
  /// with MKII hardware model IDs (nuxIndex 1..11).
  static List<Modulation> createModulationList() {
    return [
      _Mk2ModCE1(),
      _Mk2ModCE2(),
      _Mk2STChorus(),
      _Mk2Vibrato(),
      _Mk2Flanger(),
      _Mk2Phase90(),
      _Mk2Phase100(),
      _Mk2SCF(),
      _Mk2Vibe(),
      _Mk2Tremolo(),
      _Mk2SCH1(),
    ];
  }

  /// Delay models available on the Mighty 20 MKII, in the correct order,
  /// with MKII hardware model IDs (nuxIndex 1..5). Pan Delay is not available;
  /// Phi Delay is the 5th delay.
  static List<DelayPro> createDelayList() {
    return [
      AnalogDelayV2(),
      DigitalDelay(),
      ModDelay(),
      TapeEcho(),
      _Mk2PhiDelay(),
    ];
  }

  /// Reverb models available on the Mighty 20 MKII, in the correct order,
  /// with MKII hardware model IDs (nuxIndex 1..5). Shimmer is not available;
  /// Damp is the 5th reverb.
  static List<Reverb> createReverbList() {
    return [
      RoomReverb(),
      HallReverb(),
      PlateReverb(),
      SpringReverb(),
      _Mk2DampReverb(),
    ];
  }

  @override
  Color get channelColor => channelColorsList[(channel ~/ 3) % channelColorsList.length];

  List<int> get visibleSlotIndices {
    final slots = <int>[];
    for (int i = 0; i < processorAtSlot.length; i++) {
      if (processorAtSlot[i] != PlugProFXID.cab) slots.add(i);
    }
    return slots;
  }
}

class _Mk2ModCE1 extends ModCE1 {
  @override
  int get nuxIndex => 1;
}

class _Mk2ModCE2 extends ModCE2 {
  @override
  int get nuxIndex => 2;
}

class _Mk2STChorus extends STChorusPro {
  @override
  int get nuxIndex => 3;
}

class _Mk2Vibrato extends Vibrato {
  @override
  int get nuxIndex => 4;
}

class _Mk2Flanger extends FlangerPro {
  @override
  int get nuxIndex => 5;
}

class _Mk2Phase90 extends Phase90 {
  @override
  int get nuxIndex => 6;
}

class _Mk2Phase100 extends Phase100 {
  @override
  int get nuxIndex => 7;
}

class _Mk2SCF extends SCFPro {
  @override
  int get nuxIndex => 8;
}

class _Mk2Vibe extends VibePro {
  @override
  int get nuxIndex => 9;
}

class _Mk2Tremolo extends TremoloPro {
  @override
  int get nuxIndex => 10;
}

class _Mk2SCH1 extends SCH1Pro {
  @override
  int get nuxIndex => 11;
}

class _Mk2PhiDelay extends PhiDelayPro {
  @override
  int get nuxIndex => 5;
}

class _Mk2DampReverb extends DampReverbPro {
  @override
  int get nuxIndex => 5;
}
