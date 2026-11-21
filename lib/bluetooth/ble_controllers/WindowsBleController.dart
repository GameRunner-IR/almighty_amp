import 'dart:async';

import 'package:bluetooth_low_energy_platform_interface/bluetooth_low_energy_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:almighty_amp/utilities/list_extenstions.dart';

import 'BLEController.dart';

/// BLE controller for Windows, backed by the [bluetooth_low_energy] plugin
/// (WinRT BluetoothLEAdvertisementWatcher + GATT session).
///
/// Mirrors the behavior of the mobile controllers:
/// - scan results are filtered against the NUX amp BLE name list,
/// - connection to an amp is exclusive,
/// - the standard MIDI over BLE service/characteristic is used,
/// - outgoing data is queued and written in order.
class WindowsBleController extends BLEController {
  WindowsBleController(List<String> forcedDevices) : super(forcedDevices);

  late final CentralManager _central = _initCentral();

  /// Constructs [CentralManager], which registers the Windows platform
  /// implementation and starts BLE initialization. Subscriptions are attached
  /// in [init] so events fired during construction are not missed.
  CentralManager _initCentral() {
    debugPrint('WindowsBle: initializing CentralManager');
    return CentralManager();
  }

  BLEDevice? _connectedDevice;
  GATTCharacteristic? _midiCharacteristic;
  bool _connectInProgress = false;
  bool _linkUp = false;

  /// Whether the automatic scan (started when Bluetooth reaches `poweredOn`)
  /// is currently active. Manual scans from Settings are not tracked here.
  bool _autoScanActive = false;

  StreamController<List<int>>? _dataStreamController;

  String _nameFor(Peripheral peripheral, Advertisement advertisement) {
    final name = advertisement.name;
    if (name != null && name.isNotEmpty) return name;
    return peripheral.uuid.toString();
  }

  @override
  Future init(ScanResultsCallback callback) async {
    await super.init(callback);

    // CentralManager() registers the platform implementation and triggers
    // Windows BLE initialization; subscribing afterwards guarantees events
    // fired during construction are not missed.
    _central.discovered.listen(_onDiscovered);
    _central.connectionStateChanged.listen(_onConnectionStateChanged);
    _central.characteristicNotified.listen(_onCharacteristicNotified);
    _central.stateChanged.listen(_onStateChanged);

    bleState = BleState.on;
    setMidiSetupStatus(MidiSetupStatus.deviceIdle);

    // If Bluetooth was already powered on before the listener was attached,
    // the stateChanged event will never fire for it — check the current
    // state so the automatic scan is not missed.
    if (_central.state == BluetoothLowEnergyState.poweredOn) {
      _startAutoScan();
    }
  }

  /// Starts the automatic scan when Bluetooth becomes available.
  ///
  /// Mirrors the mobile controllers, which start scanning when the BLE state
  /// reports `on`. Guarded by [_autoScanActive] so repeated poweredOn events
  /// (Windows raises state changes more than once) do not start duplicate
  /// scans, and by [_connectInProgress]/[_connectedDevice] so no scan runs
  /// while a connection attempt or an active connection exists.
  void _startAutoScan() {
    if (_autoScanActive) return;
    if (_connectInProgress || _connectedDevice != null) return;
    _autoScanActive = true;
    debugPrint('WindowsBle: starting automatic scan (poweredOn)');
    startScanning();
  }

  /// Stops the automatic scan, e.g. when Bluetooth is turned off.
  void _stopAutoScan() {
    if (!_autoScanActive) return;
    _autoScanActive = false;
    debugPrint('WindowsBle: stopping automatic scan');
    stopScanning();
  }

  void _onStateChanged(BluetoothLowEnergyStateChangedEventArgs args) {
    debugPrint('WindowsBle: Bluetooth state changed: ${args.state}');
    switch (args.state) {
      case BluetoothLowEnergyState.poweredOn:
        _startAutoScan();
        break;
      case BluetoothLowEnergyState.poweredOff:
      case BluetoothLowEnergyState.unsupported:
      case BluetoothLowEnergyState.unauthorized:
      case BluetoothLowEnergyState.unknown:
        _stopAutoScan();
        break;
    }
  }

  @override
  Future<bool> isAvailable() async {
    // CentralManager() starts native Windows BLE initialization asynchronously
    // (BluetoothAdapter::GetDefaultAsync + GetRadioAsync). Until it completes,
    // the native GetState() reports `unsupported`, which must not be treated
    // as a real lack of Bluetooth support. Poll briefly instead.
    const pollInterval = Duration(milliseconds: 100);
    const maxWait = Duration(seconds: 5);
    final deadline = DateTime.now().add(maxWait);

    BluetoothLowEnergyState lastState = _central.state;
    debugPrint('WindowsBle: initial Bluetooth state: $lastState');

    while (true) {
      final state = _central.state;
      if (state != lastState) {
        debugPrint('WindowsBle: Bluetooth state changed: $lastState -> $state');
        lastState = state;
      }
      if (state == BluetoothLowEnergyState.poweredOn) {
        debugPrint('WindowsBle: Bluetooth ready (poweredOn)');
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        debugPrint(
            'WindowsBle: timeout after ${maxWait.inSeconds}s waiting for Bluetooth state (last: $state)');
        return false;
      }
      await Future.delayed(pollInterval);
    }
  }

  void _onDiscovered(DiscoveredEventArgs args) {
    final peripheral = args.peripheral;
    final name = _nameFor(peripheral, args.advertisement);

    final devNames = deviceListProvider.call();
    if (!devNames.containsPartial(name)) return;

    debugPrint('WindowsBle: found $name (address ${peripheral.uuid})');

    onScanResults([WindowsBleScanResult(peripheral, args.advertisement)], []);
    setMidiSetupStatus(MidiSetupStatus.deviceFound);
  }

  void _onConnectionStateChanged(
      PeripheralConnectionStateChangedEventArgs args) {
    debugPrint(
        'WindowsBle: connection state changed: ${args.state} (${args.peripheral.uuid})');

    switch (args.state) {
      case ConnectionState.connected:
        // Do not report `deviceConnected` here. WinRT raises this as soon as
        // the link is up, before the GATT services are discovered and before
        // notifications are enabled. NuxDeviceControl starts the connection
        // handshake (firmware/preset requests) on `deviceConnected`, so the
        // status is reported from connectToDevice once the MIDI characteristic
        // can actually write and receive.
        _linkUp = true;
        break;
      case ConnectionState.disconnected:
        _linkUp = false;
        _midiCharacteristic = null;
        _connectInProgress = false;
        if (_connectedDevice != null &&
            _connectedDevice!.id == args.peripheral.uuid.toString()) {
          _connectedDevice = null;
          setMidiSetupStatus(MidiSetupStatus.deviceDisconnected);
        }
        break;
    }
  }

  void _onCharacteristicNotified(GATTCharacteristicNotifiedEventArgs args) {
    final value = args.value;
    if (value.isEmpty) return;
    _dataStreamController?.add(List<int>.from(value));
  }

  @override
  BLEDevice? get connectedDevice => _connectedDevice;

  @override
  Future<BLEConnection?> connectToDevice(BLEDevice device) async {
    final ownDevice = device as WindowsBleDevice;
    final peripheral = ownDevice.peripheral;

    bool ampDevice = false;
    if (deviceListProvider.call().containsPartial(device.name)) {
      ampDevice = true;
      if (_connectInProgress || _connectedDevice != null) {
        debugPrint("WindowsBle: Denying secondary connection!");
        return null;
      }
    }

    _connectInProgress = true;
    stopScanning();
    setMidiSetupStatus(MidiSetupStatus.deviceConnecting);

    try {
      await _central.connect(peripheral);
    } catch (e) {
      debugPrint("WindowsBle: connect error $e");
      _connectInProgress = false;
      _linkUp = false;
      return null;
    }

    if (ampDevice) {
      if (_connectedDevice != null) {
        _abortConnection(peripheral, ampDevice);
        return null;
      }
      _connectedDevice = device;
    }

    final services = await _central.discoverGATT(peripheral);
    GATTCharacteristic? midiCharacteristic;
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BLEController.midiServiceGuid) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() ==
              BLEController.midiCharacteristicGuid) {
            midiCharacteristic = characteristic;
            break;
          }
        }
      }
      if (midiCharacteristic != null) break;
    }

    if (midiCharacteristic == null) {
      debugPrint("WindowsBle: MIDI service/characteristic not found");
      _abortConnection(peripheral, ampDevice);
      return null;
    }

    if (!_linkUp) {
      debugPrint("WindowsBle: link lost during GATT discovery");
      _abortConnection(peripheral, ampDevice);
      return null;
    }

    // Create the receive stream before enabling notifications so data that
    // arrives right after subscribing has somewhere to go.
    final dataStream = _dataStream();
    _midiCharacteristic = midiCharacteristic;

    try {
      await _central.setCharacteristicNotifyState(
        peripheral,
        midiCharacteristic,
        state: true,
      );
    } catch (e) {
      debugPrint("WindowsBle: enabling notifications failed $e");
    }

    _connectInProgress = false;
    _stopAutoScan();

    if (ampDevice) {
      debugPrint("WindowsBle: amp device connected ${device.name}");
      // The MIDI characteristic can now write and receive, so the connection
      // is usable. This status starts the NuxDeviceControl handshake.
      setMidiSetupStatus(MidiSetupStatus.deviceConnected);
    }
    return BLEConnection(dataStream);
  }

  /// Cleans up a failed connection attempt so a new one can be started.
  void _abortConnection(Peripheral peripheral, bool ampDevice) {
    _connectInProgress = false;
    _linkUp = false;
    _midiCharacteristic = null;
    if (ampDevice) _connectedDevice = null;
    _central.disconnect(peripheral).catchError((e) {
      debugPrint("WindowsBle: cleanup disconnect error $e");
    });
  }

  Stream<List<int>> _dataStream() {
    _dataStreamController ??= StreamController<List<int>>.broadcast();
    return _dataStreamController!.stream;
  }

  @override
  StreamSubscription<List<int>> registerDataListener(
      Function(List<int>) listener) {
    return _dataStream().listen(listener);
  }

  @override
  void startScanning() {
    // A manual scan (Settings page) replaces the automatic one; it is stopped
    // by the caller's own Stop Scanning button, so the auto flag must not
    // keep stopping it later.
    _autoScanActive = false;
    setMidiSetupStatus(MidiSetupStatus.deviceSearching);
    _central.startDiscovery().catchError((e) {
      debugPrint("WindowsBle: startDiscovery error $e");
    });
    setScanningStatus(true);
  }

  @override
  void stopScanning() {
    _central.stopDiscovery().catchError((e) {
      debugPrint("WindowsBle: stopDiscovery error $e");
    });
    setScanningStatus(false);
  }

  @override
  void disconnectDevice() {
    final device = _connectedDevice;
    if (device == null) return;
    final ownDevice = device as WindowsBleDevice;
    _central.disconnect(ownDevice.peripheral).catchError((e) {
      debugPrint("WindowsBle: disconnect error $e");
    });
    _midiCharacteristic = null;
    _connectInProgress = false;
    _connectedDevice = null;
    setMidiSetupStatus(MidiSetupStatus.deviceDisconnected);
  }

  @override
  Future<void> dispose() async {
    await _dataStreamController?.close();
    _dataStreamController = null;
  }

  @override
  bool get isWriteReady => _midiCharacteristic != null;

  @override
  Future writeToCharacteristic(List<int> data, bool noResponse) async {
    final characteristic = _midiCharacteristic;
    final device = _connectedDevice;
    if (characteristic == null || device == null) return;

    final ownDevice = device as WindowsBleDevice;
    await _central.writeCharacteristic(
      ownDevice.peripheral,
      characteristic,
      value: Uint8List.fromList(data),
      type: noResponse
          ? GATTCharacteristicWriteType.withoutResponse
          : GATTCharacteristicWriteType.withResponse,
    );
  }
}

class WindowsBleScanResult extends BLEScanResult {
  @override
  String get id => (device as WindowsBleDevice).id;

  @override
  String get name => (device as WindowsBleDevice).name;

  WindowsBleScanResult(Peripheral peripheral, Advertisement advertisement) {
    device = WindowsBleDevice(peripheral, advertisement);
  }
}

class WindowsBleDevice extends BLEDevice {
  final Peripheral peripheral;
  final Advertisement advertisement;
  final String _name;

  WindowsBleDevice(this.peripheral, this.advertisement)
      : _name = advertisement.name ?? peripheral.uuid.toString();

  @override
  String get name => _name;

  @override
  String get id => peripheral.uuid.toString();

  @override
  Stream<BleDeviceState> get state => throw UnimplementedError();
}
