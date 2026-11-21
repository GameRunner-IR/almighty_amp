// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)
//

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:almighty_amp/UI/popups/alertDialogs.dart';
import 'package:almighty_amp/UI/popups/exportQRCode.dart';
import 'package:almighty_amp/bluetooth/NuxDeviceControl.dart';
import 'package:almighty_amp/platform/fileSaver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_utils/qr_utils.dart';
import '../../../bluetooth/devices/presets/Preset.dart';
import '../../../bluetooth/devices/presets/qr_import_report.dart';
import '../../../bluetooth/devices/NuxDevice.dart';
import '../../../platform/platformUtils.dart';
import '../../theme.dart';
import '../../utils.dart';
import 'effectSelector.dart';

class ChannelSelector extends StatefulWidget {
  final NuxDevice device;
  const ChannelSelector({Key? key, required this.device}) : super(key: key);

  @override
  State createState() => _ChannelSelectorState();
}

class _ChannelSelectorState extends State<ChannelSelector> {
  late List<Preset> _presets;
  EditorLayoutMode layout = EditorLayoutMode.expand;

  List<PopupMenuEntry> get qrMenu {
    final items = <PopupMenuEntry>[];
    if (!PlatformUtils.isWindows) {
      items.add(PopupMenuItem(
        value: 1,
        child: Row(
          children: <Widget>[
            Icon(
              Icons.qr_code_scanner,
              color: AppThemeConfig.contextMenuIconColor,
            ),
            const SizedBox(width: 5),
            const Text("Scan QR"),
          ],
        ),
      ));
    }
    items.add(PopupMenuItem(
      value: 2,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.qr_code_2,
            color: AppThemeConfig.contextMenuIconColor,
          ),
          const SizedBox(width: 5),
          const Text("Import QR Image"),
        ],
      ),
    ));
    items.add(PopupMenuItem(
      value: 3,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.qr_code_2,
            color: AppThemeConfig.contextMenuIconColor,
          ),
          const SizedBox(width: 5),
          const Text("Share QR"),
        ],
      ),
    ));
    return items;
  }

  @override
  void initState() {
    super.initState();
  }

  List<Widget> _createButtons(double _width) {
    var disabledColor = Theme.of(context).disabledColor;
    List<Widget> buttons = <Widget>[];

    var tooltip = "";
    _presets = widget.device.getPresetsList();
    final buttonCount = widget.device.channelsCount;
    int row1 = _width < 330 && buttonCount > 4
        ? (buttonCount / 2).ceil()
        : buttonCount;

    double width = (_width / row1).floorToDouble();
    for (int i = 0; i < buttonCount; i++) {
      final selected = i == widget.device.selectedChannel;
      final selColor = widget.device.proScenesCount > 1
          ? _presets[widget.device.selectedNuxIndex].channelColor
          : _presets[widget.device.selectedChannel].channelColor;
      final col = selected ? selColor : disabledColor;

      final channelName = widget.device.channelNames.length > i
          ? widget.device.channelNames[i]
          : _presets[i].channelName;
      Widget buttonBody;
      if (widget.device.longChannelNames) {
        tooltip = channelName;
        buttonBody = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.device.getChannelActive(i)
                  ? Icons.circle
                  : Icons.circle_outlined,
              color: col,
              size: 32,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: FittedBox(fit: BoxFit.fill, child: Text(channelName)),
            ),
          ],
        );
      } else {
        tooltip = "Channel ${i + 1}";
        buttonBody = Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              widget.device.getChannelActive(i)
                  ? Icons.circle
                  : Icons.circle_outlined,
              color: col,
              size: 32,
            ),
            Text(
              channelName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      }

      var button = GestureDetector(
        onTap: () {
          final device = widget.device;
          final samePreset = device.selectedChannel == i;
          // Devices with Pro Scenes recall scene 1 whenever the physical
          // preset is selected, even if it is already the current one.
          final resetScene =
              device.proScenesCount > 1 && device.selectedProScene != 0;
          if (samePreset && !resetScene) return;
          if (samePreset) {
            device.setSelectedProScene(0);
          } else {
            device.setSelectedChannel(i,
                notifyBT: true, sendFullPreset: false, notifyUI: true);
            device.selectedPatch.setupPresetFromNuxData();
          }
        },
        onLongPress: () {
          widget.device.toggleChannelActive(i);
        },
        child: Container(
          //use container with color to expand hittest area for the gesture detector
          //better to use the same as the background color to imitate transparency
          //than to use translucent hittest (slow)
          color: Theme.of(context).scaffoldBackgroundColor,
          width: width,
          height:
              AppThemeConfig.toggleButtonHeight(widget.device.longChannelNames),
          child: Semantics(
            selected: widget.device.selectedChannel == i,
            label: tooltip,
            child: ExcludeSemantics(child: buttonBody),
          ),
        ),
      );
      buttons.add(button);
    }

    return buttons;
  }

  /// Pro Scene selectors for devices that store several patches inside one
  /// physical preset (Mighty 20 MKII).
  Widget _createProSceneBar() {
    final device = widget.device;
    final scenesCount = device.proScenesCount;
    final selectedScene = device.selectedProScene;
    final disabledColor = Theme.of(context).disabledColor;
    final activeColor = device.selectedPatch.channelColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: disabledColor)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Pro Scene", style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            for (int i = 0; i < scenesCount; i++)
              GestureDetector(
                onTap: () => device.setSelectedProScene(i),
                child: Semantics(
                  selected: selectedScene == i,
                  label: "Pro Scene ${i + 1}",
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 46,
                      height: AppThemeConfig.toggleButtonHeight(false),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            selectedScene == i
                                ? Icons.circle
                                : Icons.circle_outlined,
                            color: selectedScene == i
                                ? activeColor
                                : disabledColor,
                            size: 30,
                          ),
                          Text(
                            "${i + 1}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  qrPopupSelection(pos) async {
    switch (pos) {
      case 1: //scan qr
        var result = await Permission.camera.request();
        if (result.isPermanentlyDenied) {
          //TODO: Explain why camera is needed and open settings
        }
        final content = await QrUtils.scanQR;
        if (content?.isNotEmpty ?? false) {
          setupFromQRData(content!);
          setState(() {});
        }
        break;
      case 2:
        if (PlatformUtils.isAndroid) {
          openFile("image/*").then((value) async {
            final content = await QrUtils.scanImageFromData(value);
            if (content != null) {
              setupFromQRData(content);
              setState(() {});
            } else {
              showQRError();
            }
          });
        } else if (PlatformUtils.isIOS) {
          final content = await QrUtils.scanImage();
          if (content != null) {
            setupFromQRData(content);
            setState(() {});
          } else {
            showQRError();
          }
        } else {
          final picker = await fs.openFiles(acceptedTypeGroups: [
            const fs.XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'])
          ]);
          if (picker.isEmpty) return;
          final bytes = await picker.first.readAsBytes();
          debugPrint('[QR-UI] picked file ${picker.first.name}, bytes=${bytes.length}');
          final content = await QrUtils.scanImageFromData(bytes);
          debugPrint('[QR-UI] scan result: ${content == null ? "null" : (content.isEmpty ? "empty" : "ok len=${content.length}")}');
          if (content != null && content.isNotEmpty) {
            setupFromQRData(content);
            setState(() {});
          } else {
            showQRError();
          }
        }
        break;
      case 3:
        var qr = widget.device.channelToQR(widget.device.selectedChannel);
        var name = widget.device.deviceControl.presetName;
        Image img = await QrUtils.generateQR(qr);
        if (name.isEmpty) {
          AlertDialogs.showInputDialog(context,
              title: "Enter preset name",
              description: "It will be displayed below the QR code.",
              value: "",
              onConfirm: (value) => {showQRExport(img, value)});
        } else
          showQRExport(img, name);
    }
  }

  void showQRExport(Image img, String name) {
    var qrExport =
        QRExportDialog(img, name, NuxDeviceControl.instance().device);
    showDialog(
      context: context,
      builder: (BuildContext context) => qrExport.buildDialog(context),
    );
  }

  void showQRError() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          "Error decoding QR code!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 20),
        )));
  }

  void setupFromQRData(String qrData) async {
    var report = widget.device.setupFromQRDataReport(qrData);
    bool success = report.isOk;
    NuxDeviceControl.instance().changes.clearHistory();
    setState(() {});

    var message = QrUtils.QRMessages[report.error.index];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: success ? Colors.green : Colors.red,
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        )));

    if (success && report.warnings.isNotEmpty) {
      await _showQrImportWarnings(report.warnings);
    }
  }

  Future<void> _showQrImportWarnings(List<QrImportWarning> warnings) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Import Warnings'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Some effects from the Plug Pro preset are not supported on Mighty 20 MKII. They were turned off during import.',
                ),
                const SizedBox(height: 12),
                for (final w in warnings) ...[
                  Text(
                    'Unsupported ${w.category}: ${w.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (w.parameters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 8),
                      child: Text('(No parameters)'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in w.parameters.entries)
                            Text('${e.key}: ${e.value}'),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    layout = getEditorLayoutMode(MediaQuery.of(context));

    _presets = widget.device.getPresetsList();

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.grey[800],
                border: Border.all(color: Theme.of(context).disabledColor),
                borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                PopupMenuButton(
                    itemBuilder: (context) {
                      return qrMenu;
                    },
                    onSelected: qrPopupSelection,
                    child: const SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 32,
                          ),
                          Text(
                            "QR Code",
                            textAlign: TextAlign.center,
                          )
                        ],
                      ),
                    )),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    color: Colors.grey[900],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Wrap(
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.center,
                              children: _createButtons(constraints.maxWidth),
                            );
                          },
                        ),
                        if (widget.device.proScenesCount > 1)
                          _createProSceneBar(),
                      ],
                    ),
                  ),
                ),
                Semantics(
                  checked: widget.device
                      .getChannelActive(widget.device.selectedChannel),
                  child: InkWell(
                    onTap: () {
                      widget.device
                          .toggleChannelActive(widget.device.selectedChannel);
                    },
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Icon(
                            widget.device.getChannelActive(
                                    widget.device.selectedChannel)
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 30,
                          ),
                          const Text("Active")
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        if (layout == EditorLayoutMode.expand)
          Expanded(
            child: EffectSelector(
                device: widget.device, preset: widget.device.selectedPatch),
          )
        else
          EffectSelector(
              device: widget.device, preset: widget.device.selectedPatch)
      ],
    );
  }
}
