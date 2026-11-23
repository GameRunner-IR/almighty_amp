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
import '../effects/plug_pro/EFX.dart';
import '../effects/plug_pro/Modulation.dart';
import '../effects/plug_pro/Reverb.dart';
import '../value_formatters/ValueFormatter.dart';
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
    efxList
      ..clear()
      ..addAll(createEfxList());
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

  /// EFX models available on the Mighty 20 MKII. The only difference from Plug
  /// Pro is Touch Wah, whose unsupported Level parameter is hidden.
  static List<EFXPro> createEfxList() {
    return [
      DistortionPlus(),
      RCBoost(),
      ACBoost(),
      DistOne(),
      TSDrive(),
      BluesDrive(),
      MorningDrive(),
      EatDist(),
      RedDirt(),
      Crunch(),
      MuffFuzz(),
      Katana(),
      STSinger(),
      _Mk2TouchWahPro(),
    ];
  }

  /// Delay models available on the Mighty 20 MKII, in the correct order,
  /// with MKII hardware model IDs (nuxIndex 1..5). Pan Delay is not available;
  /// Phi Delay is the 5th delay.
  static List<DelayPro> createDelayList() {
    return [
      _Mk2AnalogDelay(),
      _Mk2DigitalDelay(),
      _Mk2ModDelay(),
      _Mk2TapeEcho(),
      _Mk2PhiDelay(),
    ];
  }

  /// Reverb models available on the Mighty 20 MKII, in the correct order,
  /// with MKII hardware model IDs (nuxIndex 1..5). Shimmer is not available;
  /// Damp is the 5th reverb.
  static List<Reverb> createReverbList() {
    return [
      _Mk2RoomReverb(),
      _Mk2HallReverb(),
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

    // Plug Pro patch level does not map to the MKII volume curve. Normalize it
    // to 0 dB only for the Plug Pro -> MKII conversion; native MKII QR imports
    // keep their own value.
    if (converted.length > PresetDataIndexPlugPro.MASTER) {
      converted[PresetDataIndexPlugPro.MASTER] =
          device.decibelFormatter!.valueToMidi7Bit(0);
    }

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
  _Mk2Vibe() {
    // On the MKII MOD_Para3 is the real mode switch (0 = Chorus,
    // 1 = Vibrato); MOD_Para4 has no effect. Move that behaviour to the Mode
    // switch and drop the misleading Intensity slider.
    final intensity =
        parameters.firstWhere((parameter) => parameter.handle == 'intensity');
    final mode =
        parameters.firstWhere((parameter) => parameter.handle == 'mode');

    mode.devicePresetIndex = PresetDataIndexPlugPro.MOD_Para3;
    mode.midiCC = MidiCCValuesPro.MOD_Para3;
    mode.formatter = ValueFormatters.vibeModePro;
    mode.value = 0;
    mode.midiControllerHandle = intensity.midiControllerHandle;

    parameters.removeWhere((parameter) => parameter.handle == 'intensity');

    // MKII label names for the remaining controls.
    parameters.firstWhere((p) => p.handle == 'speed').name = 'Rate';
    parameters.firstWhere((p) => p.handle == 'volume').name = 'Depth';
  }

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

class _Mk2DigitalDelay extends DigitalDelay {
  _Mk2DigitalDelay() {
    final level =
        parameters.firstWhere((parameter) => parameter.handle == 'level');
    final time =
        parameters.firstWhere((parameter) => parameter.handle == 'time');
    final feedback =
        parameters.firstWhere((parameter) => parameter.handle == 'feedback');

    // On MKII DLY_Para1 is the real Time and DLY_Para3 is the real Mix.
    // Swap the two hardware controls while keeping each formatter/controller
    // with its semantic parameter.
    final levelIndex = level.devicePresetIndex;
    final levelCC = level.midiCC;
    level.devicePresetIndex = time.devicePresetIndex;
    level.midiCC = time.midiCC;
    time.devicePresetIndex = levelIndex;
    time.midiCC = levelCC;

    level.name = 'Mix';
    feedback.name = 'Repeat';
  }
}

class _Mk2ModDelay extends ModDelay {
  _Mk2ModDelay() {
    final level =
        parameters.firstWhere((parameter) => parameter.handle == 'level');
    final repeat =
        parameters.firstWhere((parameter) => parameter.handle == 'repeat');
    final mod = parameters.firstWhere((parameter) => parameter.handle == 'mod');

    // MKII hardware controls: DLY_Para2 = Repeat, DLY_Para4 = Mod,
    // DLY_Para3 = Mix. Rotate the three controls so each label drives the
    // right thing. Time (DLY_Para1) is already correct and stays as-is.
    final levelIndex = level.devicePresetIndex;
    final levelCC = level.midiCC;

    level.devicePresetIndex = mod.devicePresetIndex;
    level.midiCC = mod.midiCC;
    mod.devicePresetIndex = repeat.devicePresetIndex;
    mod.midiCC = repeat.midiCC;
    repeat.devicePresetIndex = levelIndex;
    repeat.midiCC = levelCC;

    level.name = 'Mix';
  }
}

class _Mk2TapeEcho extends TapeEcho {
  _Mk2TapeEcho() {
    final level =
        parameters.firstWhere((parameter) => parameter.handle == 'level');
    final repeat =
        parameters.firstWhere((parameter) => parameter.handle == 'repeat');

    // MKII hardware controls: DLY_Para3 = Mix, DLY_Para2 = Repeat.
    // Swap only the hardware capabilities; each slider keeps its own MIDI
    // controller handle and gets the name matching what it now controls.
    final levelIndex = level.devicePresetIndex;
    final levelCC = level.midiCC;

    level.devicePresetIndex = repeat.devicePresetIndex;
    level.midiCC = repeat.midiCC;

    repeat.devicePresetIndex = levelIndex;
    repeat.midiCC = levelCC;

    level.name = 'Mix';
    repeat.name = 'Repeat';
  }
}

class _Mk2AnalogDelay extends AnalogDelayV2 {
  _Mk2AnalogDelay() {
    // MKII labels for the same hardware controls.
    for (final parameter in parameters) {
      switch (parameter.handle) {
        case 'rate':
          parameter.name = 'Time';
          break;
        case 'intensity':
          parameter.name = 'Mix';
          break;
        case 'echo':
          parameter.name = 'Repeat';
          break;
      }
    }
  }
}

class _Mk2PhiDelay extends PhiDelayPro {
  @override
  int get nuxIndex => 5;
}

class _Mk2DampReverb extends DampReverbPro {
  _Mk2DampReverb() {
    // On the MKII the control wired to RVB_Para1 is the real Decay and the
    // one wired to RVB_Para2 is the real Level. Keep indices/handles intact.
    for (final parameter in parameters) {
      if (parameter.handle == 'mix') {
        parameter.name = 'Decay';
      } else if (parameter.handle == 'depth') {
        parameter.name = 'Level';
      }
    }
  }

  @override
  int get nuxIndex => 5;
}

/// On the MKII the Room reverb hardware labels are swapped: the control wired
/// to RVB_Para2 is the actual Level, and the one wired to RVB_Para3 is the
/// actual Tone. Keep payload indices and handles unchanged so saved presets
/// and MIDI controller assignments keep working; only swap the visible text.
class _Mk2RoomReverb extends RoomReverb {
  _Mk2RoomReverb() {
    for (final parameter in parameters) {
      if (parameter.handle == 'tone') {
        parameter.name = 'Level';
      } else if (parameter.handle == 'level') {
        parameter.name = 'Tone';
      }
    }
  }
}

/// On the MKII Hall reverb, the parameter wired to RVB_Para4 (Plug Pro's
/// "Level") has no effect, so it is removed. RVB_Para2 is the real Level and
/// RVB_Para3 is the real Tone. Handles and payload indices stay unchanged.
class _Mk2HallReverb extends HallReverb {
  _Mk2HallReverb() {
    parameters.removeWhere((parameter) => parameter.handle == 'level');
    for (final parameter in parameters) {
      if (parameter.handle == 'predelay') {
        parameter.name = 'Level';
      } else if (parameter.handle == 'liveliness') {
        parameter.name = 'Tone';
      }
    }
  }
}

/// MKII Touch Wah keeps the same hardware model ID, but its Level parameter
/// and Up/Down Switch are not supported by the device. Removing them from the
/// parameter list hides their sliders and prevents the unused CCs from being
/// sent. Plug Pro's own TouchWahPro instance is untouched.
class _Mk2TouchWahPro extends TouchWahPro {
  _Mk2TouchWahPro() {
    // The MKII supports neither the Touch Wah Level nor its Up/Down Switch.
    parameters.removeWhere((parameter) =>
        parameter.handle == 'level' || parameter.handle == 'direction');
  }
}
