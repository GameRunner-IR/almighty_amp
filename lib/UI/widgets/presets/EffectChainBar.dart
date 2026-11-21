import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mighty_plug_manager/bluetooth/devices/NuxDevice.dart';

import '../../../bluetooth/devices/presets/Mighty20Mk2Preset.dart';
import '../../../bluetooth/devices/presets/Preset.dart';
import 'EffectChainButton.dart';

class EffectChainBar extends StatelessWidget {
  static const double effectsChainPadding = 6;

  final double maxHeight;
  final NuxDevice device;
  final Preset preset;
  final bool reorderable;
  final void Function(int) onTap;
  final void Function(int) onDoubleTap;
  final ReorderCallback onReorder;

  const EffectChainBar(
      {Key? key,
      required this.maxHeight,
      required this.device,
      required this.preset,
      required this.onTap,
      required this.onDoubleTap,
      required this.onReorder,
      required this.reorderable})
      : super(key: key);

  List<int> get _visibleSlotIndices {
    final indices = preset is Mighty20Mk2Preset
        ? (preset as Mighty20Mk2Preset).visibleSlotIndices
        : List<int>.generate(device.effectsChainLength, (i) => i);
    // Some devices/firmware may report slots (e.g. WAH/SR) that are not
    // represented in the UI processor list; skip them to avoid null crashes.
    return indices
        .where((i) => device.getProcessorInfoByFXID(preset.getFXIDFromSlot(i)) != null)
        .toList();
  }

  EffectChainButton buildItem(context, index) {
    final slotIndex = _visibleSlotIndices[index];
    var proc = preset.getFXIDFromSlot(slotIndex);
    var effect = device.getProcessorInfoByFXID(proc)!;
    bool selected = slotIndex == device.selectedSlot;

    return EffectChainButton(
        index: slotIndex,
        effectInfo: effect,
        color: preset.effectColor(slotIndex),
        enabled: preset.slotEnabled(slotIndex),
        selected: selected,
        reorderable: reorderable,
        key: Key(slotIndex.toString()),
        onTap: () => onTap(slotIndex),
        onDoubleTap: () => onDoubleTap(slotIndex));
  }

  @override
  Widget build(BuildContext context) {
    final visibleSlotIndices = _visibleSlotIndices;
    final visibleSlotCount = visibleSlotIndices.length;

    double constrainHeight = max(
        min(
            (MediaQuery.of(context).size.width - effectsChainPadding * 2) /
                visibleSlotCount /
                0.8,
            maxHeight),
        10);

    Widget list;
    if (reorderable) {
      list = ReorderableList(
        padding: const EdgeInsets.symmetric(horizontal: effectsChainPadding),
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleSlotCount,
        proxyDecorator: (widget, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double animValue =
                  Curves.easeInOut.transform(animation.value);
              final double offset = lerpDouble(0, -15, animValue)!;
              return Material(
                color: Colors.transparent,
                child: Transform.translate(
                  offset: Offset(0, offset),
                  child: widget,
                ),
              );
            },
          );
        },
        itemBuilder: buildItem,
        onReorder: (a, b) {
          if (b > a) b--;
          final slots = visibleSlotIndices;
          onReorder(slots[a], slots[b]);
        },
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: effectsChainPadding),
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleSlotCount,
        itemBuilder: buildItem,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: constrainHeight),
      child: list,
    );
  }
}
