// Verifies that amps which only exist on the Plug Pro are not selectable on the
// NUX Mighty 20 MKII.

import 'package:flutter_test/flutter_test.dart';
import 'package:mighty_plug_manager/bluetooth/devices/effects/plug_pro/Amps.dart';
import 'package:mighty_plug_manager/bluetooth/devices/presets/Mighty20Mk2Preset.dart';

void main() {
  test('Plug Pro only amps are unavailable on the MKII', () {
    expect(Mighty20Mk2Preset.isAmpAvailable(AGL()), isFalse);
    expect(Mighty20Mk2Preset.isAmpAvailable(MLD()), isFalse);
    expect(Mighty20Mk2Preset.isAmpAvailable(OptimaAir()), isFalse);
    expect(Mighty20Mk2Preset.isAmpAvailable(Stageman()), isFalse);
  });

  test('shared amps stay available on the MKII', () {
    expect(Mighty20Mk2Preset.isAmpAvailable(JazzClean()), isTrue);
    expect(Mighty20Mk2Preset.isAmpAvailable(DeluxeRvb()), isTrue);
    expect(Mighty20Mk2Preset.isAmpAvailable(Plexi100()), isTrue);
    expect(Mighty20Mk2Preset.isAmpAvailable(UberHiGain()), isTrue);
    // Brit2000 and MrZ38 sit next to the removed amps in the Plug Pro list.
    expect(Mighty20Mk2Preset.isAmpAvailable(Brit2000()), isTrue);
    expect(Mighty20Mk2Preset.isAmpAvailable(MrZ38()), isTrue);
  });
}
