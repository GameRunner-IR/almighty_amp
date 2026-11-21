// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import 'package:flutter/material.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import '../../bluetooth/devices/presets/Preset.dart';
import '../widgets/scrollParent.dart';
import '../../bluetooth/devices/NuxDevice.dart';
import '../../platform/presetsStorage.dart';
import 'alertDialogs.dart';

class SavePresetDialog {
  final _formKey = GlobalKey<FormState>();
  final categoryCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final parentScroll = ScrollController();
  final String? customName;
  final Preset? customPreset;
  final NuxDevice device;
  final Color? confirmColor;
  late NuxDeviceControl deviceControl;

  SavePresetDialog(
      {required this.device,
      this.confirmColor,
      this.customName,
      this.customPreset}) {
    deviceControl = device.deviceControl;
    categoryCtrl.text = deviceControl.presetCategory;
    if (customName != null) {
      nameCtrl.text = customName!;
    } else {
      nameCtrl.text = deviceControl.presetName;
    }
  }

  Widget buildDialog(NuxDevice device, BuildContext context) {
    List<String> categories = PresetsStorage().getCategories();

    var isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final height = MediaQuery.of(context).size.height * 0.25;
    final node = FocusScope.of(context);

    return StatefulBuilder(
      builder: (context, setState) {
        var dialog = AlertDialog(
          title: const Text('Save preset'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              reverse: true,
              controller: parentScroll,
              child: Form(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                key: _formKey,
                child: Column(
                  children: [
                    Text("Categories",
                        style: TextStyle(color: Theme.of(context).hintColor)),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      height: height,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ScrollParent(
                        controller: parentScroll,
                        child: ListTileTheme(
                          child: ListView.builder(
                            physics: const ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(categories[index]),
                                onTap: () {
                                  setState(() {
                                    categoryCtrl.text = categories[index];
                                  });
                                },
                              );
                            },
                            itemCount: categories.length,
                          ),
                        ),
                      ),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Category"),
                      controller: categoryCtrl,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter preset category';
                        }
                        return null;
                      },
                      onEditingComplete: () => node.nextFocus(),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: "Name"),
                      controller: nameCtrl,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter preset name';
                        }
                        return null;
                      },
                      onEditingComplete: () => node.unfocus(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  try {
                    if (PresetsStorage().presetExists(
                        nameCtrl.value.text, categoryCtrl.value.text)) {
                      AlertDialogs.showConfirmDialog(context,
                          title: "Confirm",
                          description: "Overwrite existing preset?",
                          cancelButton: "Cancel",
                          confirmButton: "Overwrite",
                          confirmColor: Colors.red, onConfirm: (overwrite) {
                        if (overwrite) {
                          try {
                            savePreset(context);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            if (context.mounted) {
                              AlertDialogs.showInfoDialog(context,
                                  title: "Error",
                                  description: "Failed to save preset: $e",
                                  confirmButton: "OK");
                            }
                          }
                        }
                      });
                    } else {
                      savePreset(context);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AlertDialogs.showInfoDialog(context,
                          title: "Error",
                          description: "Failed to save preset: $e",
                          confirmButton: "OK");
                    }
                  }
                }
              },
              child: Text(
                'Save',
                style: TextStyle(color: confirmColor),
              ),
            ),
          ],
        );

        if (isPortrait) {
          return dialog;
        } else {
          return SingleChildScrollView(
            child: dialog,
          );
        }
      },
    );
  }

  savePreset(context) {
    var preset = device.presetToJson(customPreset: customPreset);
    if (customPreset == null) {
      deviceControl.presetName = nameCtrl.value.text;
      deviceControl.presetCategory = categoryCtrl.value.text;
    }

    String uuid = PresetsStorage()
        .savePreset(preset, nameCtrl.value.text, categoryCtrl.value.text);

    if (customPreset == null) {
      deviceControl.presetUUID = uuid;
    }
  }
}
