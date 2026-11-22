import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'platformUtils.dart';

Future<String> saveFileString(String mime, String name, String data) async {
  if (PlatformUtils.isWindows) {
    var ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) {
      const mimeExt = {
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'application/json': 'json',
        'text/plain': 'txt',
      };
      ext = mimeExt[mime.toLowerCase()] ?? '';
    }
    final suggested = ext.isNotEmpty && !name.toLowerCase().endsWith('.$ext')
        ? '$name.$ext'
        : name;
    final location = await fs.getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: ext.isEmpty
          ? const <fs.XTypeGroup>[]
          : [fs.XTypeGroup(label: ext.toUpperCase(), extensions: [ext])],
    );
    if (location == null) return "";
    var savePath = location.path;
    if (ext.isNotEmpty && p.extension(savePath).isEmpty) {
      savePath = '$savePath.$ext';
    }
    final file = File(savePath);
    await file.writeAsString(data);
    return file.path;
  }
  const platform =
      MethodChannel("com.msvcode.filesaver/files"); //unique channel identifier
  try {
    final result = await platform.invokeMethod("saveFile", {
      "mime": mime,
      "name": name,
      "data": data,
      "byteArray": false
    }); //name in native code

    return result;
  } on PlatformException {
    return Future.error("Error saving file");
  }
}

Future<String> saveFile(String mime, String name, List<int> data) async {
  if (PlatformUtils.isWindows) {
    var ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) {
      const mimeExt = {
        'image/png': 'png',
        'image/jpeg': 'jpg',
        'application/json': 'json',
        'text/plain': 'txt',
      };
      ext = mimeExt[mime.toLowerCase()] ?? '';
    }
    final suggested = ext.isNotEmpty && !name.toLowerCase().endsWith('.$ext')
        ? '$name.$ext'
        : name;
    final location = await fs.getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: ext.isEmpty
          ? const <fs.XTypeGroup>[]
          : [fs.XTypeGroup(label: ext.toUpperCase(), extensions: [ext])],
    );
    if (location == null) return "";
    var savePath = location.path;
    if (ext.isNotEmpty && p.extension(savePath).isEmpty) {
      savePath = '$savePath.$ext';
    }
    final file = File(savePath);
    await file.writeAsBytes(data);
    return file.path;
  }
  const platform =
      MethodChannel("com.msvcode.filesaver/files"); //unique channel identifier
  try {
    final result = await platform.invokeMethod("saveFile", {
      "mime": mime,
      "name": name,
      "data": data,
      "byteArray": true
    }); //name in native code

    return result;
  } on PlatformException {
    return Future.error("Error saving file");
  }
}

Future<String?> openFileString(String mime) async {
  if (PlatformUtils.isWindows) {
    final fs.XFile? file = await fs.openFile(acceptedTypeGroups: [
      const fs.XTypeGroup(
          label: 'Presets', extensions: ['nuxpreset', 'json']),
      const fs.XTypeGroup(label: 'All files'),
    ]);
    if (file == null) return null;
    return file.readAsString();
  }
  const platform =
      MethodChannel("com.msvcode.filesaver/files"); //unique channel identifier
  try {
    final result = await platform.invokeMethod<String?>(
        "openFile", {"mime": mime, "byte_array": false}); //name in native code

    return result;
  } on PlatformException {
    //fails native call
    //handle error
    return Future.error("Can't open text file");
  }
}

Future<List<int>> openFile(String mime) async {
  const platform =
      MethodChannel("com.msvcode.filesaver/files"); //unique channel identifier
  try {
    final result = await platform.invokeMethod(
        "openFile", {"mime": mime, "byte_array": true}); //name in native code

    return result;
  } on PlatformException {
    //fails native call
    //handle error
    return Future.error("Can't open byte array file");
  }
}
