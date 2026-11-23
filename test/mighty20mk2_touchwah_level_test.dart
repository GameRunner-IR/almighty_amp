// Verifies that the unsupported Touch Wah Level and Up/Down Switch sliders are
// removed only on the Mighty 20 MKII and that Plug Pro keeps its parameters.

import 'package:flutter_test/flutter_test.dart';
import 'package:almighty_amp/bluetooth/devices/effects/plug_pro/EFX.dart';
import 'package:almighty_amp/bluetooth/devices/presets/Mighty20Mk2Preset.dart';

void main() {
  test('Touch Wah Level and Up/Down Switch are hidden on MKII only', () {
    final mk2TouchWah =
        Mighty20Mk2Preset.createEfxList().whereType<TouchWahPro>().single;
    final mk2Handles = mk2TouchWah.parameters.map((p) => p.handle).toList();

    expect(mk2TouchWah.nuxIndex, 14);
    expect(mk2Handles, contains('type'));
    expect(mk2Handles, contains('wow'));
    expect(mk2Handles, contains('sense'));
    expect(mk2Handles, isNot(contains('level')));
    expect(mk2Handles, isNot(contains('direction')));

    final plugProTouchWah = TouchWahPro();
    final plugProHandles =
        plugProTouchWah.parameters.map((p) => p.handle).toList();

    expect(plugProHandles, contains('level'));
    expect(plugProHandles, contains('direction'));
  });
}
