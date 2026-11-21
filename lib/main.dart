// (c) 2020-2021 Dian Iliev (Tuntorius)
// This code is licensed under MIT license (see LICENSE.md for details)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:almighty_amp/UI/pages/DebugConsolePage.dart';
import 'package:almighty_amp/platform/presetsStorage.dart';
import 'package:almighty_amp/platform/simpleSharedPrefs.dart';

//pages
import 'UI/mainTabs.dart';
import 'UI/theme.dart';
import 'audio/trackdata/trackData.dart';
import 'bluetooth/NuxDeviceControl.dart';

//recreate this file with your own api keys
//import 'configKeys.dart';
import 'modules/cloud/cloudManager.dart';

//able to create snackbars/messages everywhere
final navigatorKey = GlobalKey<NavigatorState>();
final bucketGlobal = PageStorageBucket();

void main() {
  runZoned(() {
    //configuration data is needed before start of the app
    WidgetsFlutterBinding.ensureInitialized();
    SharedPrefs prefs = SharedPrefs();

    prefs.waitLoading().then((value) {
      PresetsStorage storage = PresetsStorage();
      storage.init().then((value) => mainRunApp());
    });
  }, zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
    parent.print(zone, line);
    DebugConsole.print(line);
  }));
}

mainRunApp() {
  if (kDebugMode) CloudManager.instance.initialize();

  // Run the app within a zone
  runApp(const App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State createState() => _AppState();
}

class _AppState extends State<App> {
  NuxDeviceControl device = NuxDeviceControl.instance();
  SharedPrefs prefs = SharedPrefs();
  TrackData trackData = TrackData();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Almighty Amp',
      theme: getTheme(),
      home: MainTabs(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown
        },
      ),
      //showSemanticsDebugger: true,
      navigatorKey: navigatorKey,
    );
  }
}
