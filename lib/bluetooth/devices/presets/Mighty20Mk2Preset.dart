// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:qr_utils/qr_utils.dart';

import '../NuxConstants.dart';
import '../NuxFXID.dart';
import '../effects/Processor.dart';
import '../effects/plug_pro/Amps.dart';
import '../effects/plug_pro/Delay.dart';
import '../effects/plug_pro/Modulation.dart';
import '../effects/plug_pro/Reverb.dart';
import 'PlugProPreset.dart';
import 'qr_import_report.dart';

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

  static const int _plugProQrId = 15;
  static const int _plugProQrVersion = 1;

  @override
  QrImportReport setupPresetFromQRDataReport(String qrData,
      {bool sendToDevice = true}) {
    if (!qrData.contains(QrUtils.nuxQRPrefix)) {
      return const QrImportReport(PresetQRError.UnsupportedFormat);
    }

    final b64Data = qrData.substring(QrUtils.nuxQRPrefix.length);
    final data = base64Decode(b64Data);
    if (data.length < 3) {
      return const QrImportReport(PresetQRError.UnsupportedFormat);
    }

    final qrId = data[0];
    final qrVer = data[1];

    if (qrId == device.deviceQRId && qrVer == device.deviceQRVersion) {
      final payload = List<int>.from(data.sublist(2));
      _scrubCabFromPayload(payload);
      setupPresetFromNuxDataArray(payload);
      if (sendToDevice) device.deviceControl.sendFullPresetSettings();
      return QrImportReport.ok;
    }

    if (qrId == _plugProQrId && qrVer == _plugProQrVersion) {
      return _importFromPlugProQr(data.sublist(2), sendToDevice: sendToDevice);
    }

    if (qrId != device.deviceQRId) {
      return const QrImportReport(PresetQRError.WrongDevice);
    }
    return const QrImportReport(PresetQRError.WrongFWVersion);
  }

  QrImportReport _importFromPlugProQr(List<int> nuxData,
      {required bool sendToDevice}) {
    final warnings = <QrImportWarning>[];
    final converted = List<int>.from(nuxData);

    _convertPlugProEffect(
      converted,
      nuxData,
      PresetDataIndexPlugPro.Head_iAMP,
      _plugProAmps(),
      isSupported: (p) => isAmpAvailable(p as Amplifier),
      mk2NuxIndex: (p) => p.nuxIndex,
      mk2Default: amplifierList.first,
      category: 'Amp',
      warnings: warnings,
    );
    _convertPlugProEffect(
      converted,
      nuxData,
      PresetDataIndexPlugPro.Head_iMOD,
      _plugProMods(),
      isSupported: (p) => _mk2ModNuxIndex(p.nuxIndex) != null,
      mk2NuxIndex: (p) => _mk2ModNuxIndex(p.nuxIndex)!,
      mk2Default: modulationList.first,
      category: 'Mod',
      warnings: warnings,
    );
    _convertPlugProEffect(
      converted,
      nuxData,
      PresetDataIndexPlugPro.Head_iDLY,
      _plugProDelays(),
      isSupported: (p) => _mk2DelayNuxIndex(p.nuxIndex) != null,
      mk2NuxIndex: (p) => _mk2DelayNuxIndex(p.nuxIndex)!,
      mk2Default: delayList.first,
      category: 'Delay',
      warnings: warnings,
    );
    _convertPlugProEffect(
      converted,
      nuxData,
      PresetDataIndexPlugPro.Head_iRVB,
      _plugProReverbs(),
      isSupported: (p) => _mk2ReverbNuxIndex(p.nuxIndex) != null,
      mk2NuxIndex: (p) => _mk2ReverbNuxIndex(p.nuxIndex)!,
      mk2Default: reverbList.first,
      category: 'Reverb',
      warnings: warnings,
    );

    // IR/CAB must be completely ignored when importing Plug Pro QR into MKII.
    _scrubCabFromPayload(converted);

    setupPresetFromNuxDataArray(converted);
    if (sendToDevice) device.deviceControl.sendFullPresetSettings();
    return QrImportReport(PresetQRError.Ok, warnings);

  }

  void _scrubCabFromPayload(List<int> payload) {
    if (payload.length > PresetDataIndexPlugPro.Head_iCAB &&
        cabinetList.isNotEmpty) {
      // Use a fresh default cab instance; never import IR/CAB from QR.
      final defaultCab = cabinetList.first;
      defaultCab.getNuxPayload(payload, true);
    }
  }

  void _convertPlugProEffect(
    List<int> converted,
    List<int> source,
    int effectTypeIndex,
    List<Processor> plugProList, {
    required bool Function(Processor) isSupported,
    required int Function(Processor) mk2NuxIndex,
    required Processor mk2Default,
    required String category,
    required List<QrImportWarning> warnings,
  }) {
    if (effectTypeIndex >= source.length) return;
    final effectParam = source[effectTypeIndex];
    final effectIndex = effectParam & 0x3f;

    Processor? ppEffect;
    for (final p in plugProList) {
      if (p.nuxIndex == effectIndex) {
        ppEffect = p;
        break;
      }
    }
    if (ppEffect == null || isSupported(ppEffect)) {
      if (ppEffect != null) {
        final newIndex = mk2NuxIndex(ppEffect);
        converted[effectTypeIndex] = (effectParam & 0xc0) | (newIndex & 0x3f);
      }
      return;
    }

    // Unsupported on MKII: report original Plug Pro params, then replace this
    // slot with a safe disabled MKII default. We must not keep the Plug Pro
    // nuxIndex because it can collide with a different MKII effect model.
    ppEffect.setupFromNuxPayload(source);
    final params = <String, String>{};
    for (final param in ppEffect.parameters) {
      params[param.name] = param.formatter.toLabel(param.value);
    }
    warnings.add(QrImportWarning(
      category: category,
      name: ppEffect.name,
      parameters: params,
    ));

    mk2Default.getNuxPayload(converted, false);
  }

  static int? _mk2ModNuxIndex(int plugProNuxIndex) {
    const map = {
      1: 1, // CE-1
      2: 2, // CE-2
      3: 3, // ST Chorus
      4: 4, // Vibrato
      6: 5, // Flanger
      7: 6, // Phase 90
      8: 7, // Phase 100
      9: 8, // S.C.F
      10: 9, // U-Vibe
      11: 10, // Tremolo
      13: 11, // SCH-1
    };
    return map[plugProNuxIndex];
  }

  static int? _mk2DelayNuxIndex(int plugProNuxIndex) {
    const map = {
      1: 1,
      2: 2,
      3: 3,
      4: 4,
      6: 5, // Phi Delay
    };
    return map[plugProNuxIndex];
  }

  static int? _mk2ReverbNuxIndex(int plugProNuxIndex) {
    const map = {
      1: 1,
      2: 2,
      3: 3,
      4: 4,
      6: 5, // Damp
    };
    return map[plugProNuxIndex];
  }

  static List<Processor> _plugProMods() => [
        ModCE1(),
        ModCE2(),
        STChorusPro(),
        Vibrato(),
        Detune(),
        FlangerPro(),
        Phase90(),
        Phase100(),
        SCFPro(),
        VibePro(),
        TremoloPro(),
        Rotary(),
        SCH1Pro(),
        MonoOctave(),
      ];

  static List<Processor> _plugProDelays() => [
        AnalogDelayV2(),
        DigitalDelay(),
        ModDelay(),
        TapeEcho(),
        PanDelay(),
        PhiDelayPro(),
      ];

  static List<Processor> _plugProReverbs() => [
        RoomReverb(),
        HallReverb(),
        PlateReverb(),
        SpringReverb(),
        ShimmerReverb(),
        DampReverbPro(),
      ];

  static List<Processor> _plugProAmps() => [
        JazzClean(),
        DeluxeRvb(),
        BassMate(),
        Tweedy(),
        TwinRvb(),
        HiWire(),
        CaliCrunch(),
        ClassA15(),
        ClassA30(),
        Plexi100(),
        Plexi45(),
        Brit800(),
        Pl1987x50(),
        Slo100(),
        FiremanHBE(),
        DualRect(),
        DIEVH4(),
        VibroKing(),
        Budda(),
        MrZ38(),
        SuperRvb(),
        BritBlues(),
        MatchD30(),
        Brit2000(),
        UberHiGain(),
        AGL(),
        MLD(),
        OptimaAir(),
        Stageman(),
      ];
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
