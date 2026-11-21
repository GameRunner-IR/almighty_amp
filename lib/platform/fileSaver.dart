import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'platformUtils.dart';

Future<String> saveFileString(String mime, String name, String data) async {
  if (PlatformUtils.isWindows) {
    final ext = p.extension(name).replaceFirst('.', '');
    final suggested = ext.isEmpty ? name : name;
    final location = await fs.getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: [
        fs.XTypeGroup(label: ext.isEmpty ? 'File' : ext.toUpperCase(), extensions: ext.isEmpty ? null : [ext])
      ],
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
    final ext = p.extension(name).replaceFirst('.', '');
    final suggested = ext.isEmpty ? name : name;
    final location = await fs.getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: [
        fs.XTypeGroup(label: ext.isEmpty ? 'File' : ext.toUpperCase(), extensions: ext.isEmpty ? null : [ext])
      ],
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

Future<String> openFileString(String mime) async {
  const platform =
      MethodChannel("com.msvcode.filesaver/files"); //unique channel identifier
  try {
    final result = await platform.invokeMethod(
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
