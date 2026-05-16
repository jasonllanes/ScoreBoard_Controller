import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDevice {
  final BluetoothDevice device;
  BluetoothCharacteristic? characteristic;
  bool isConnecting = false;
  bool isConnected = false;

  BleDevice(this.device);

  String get name => device.platformName.isNotEmpty
      ? device.platformName
      : device.remoteId.str;
}

class BleService extends ChangeNotifier {
  static const String _serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String _characteristicUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const int _maxConnections = 4;

  final List<BleDevice> _connectedDevices = [];
  final List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  List<BleDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  bool get isScanning => _isScanning;
  int get connectionCount => _connectedDevices.length;

  // ── Scanning ─────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (_isScanning) return;
    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults.clear();
      _scanResults.addAll(results);
      notifyListeners();
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && _isScanning) {
        _isScanning = false;
        notifyListeners();
      }
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  // ── Connection ───────────────────────────────────────────────────────────

  Future<void> connect(BluetoothDevice device) async {
    if (_connectedDevices.length >= _maxConnections) return;
    if (_connectedDevices.any((d) => d.device.remoteId == device.remoteId)) {
      return;
    }

    final ble = BleDevice(device);
    ble.isConnecting = true;
    _connectedDevices.add(ble);
    notifyListeners();

    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == _serviceUuid) {
          for (final ch in svc.characteristics) {
            if (ch.uuid.toString().toLowerCase() == _characteristicUuid) {
              ble.characteristic = ch;
              break;
            }
          }
        }
      }
      ble.isConnected = ble.characteristic != null;
      ble.isConnecting = false;

      // Auto-remove on disconnect
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevices.removeWhere(
            (d) => d.device.remoteId == device.remoteId,
          );
          notifyListeners();
        }
      });
    } catch (_) {
      _connectedDevices.remove(ble);
      ble.isConnecting = false;
    }
    notifyListeners();
  }

  Future<void> disconnect(BluetoothDevice device) async {
    _connectedDevices.removeWhere((d) => d.device.remoteId == device.remoteId);
    await device.disconnect();
    notifyListeners();
  }

  // ── Data sending ─────────────────────────────────────────────────────────

  /// Send a single ASCII command byte (button press) to all connected devices.
  Future<void> sendCommand(int asciiCode) async {
    final data = [asciiCode];
    for (final ble in _connectedDevices) {
      if (ble.isConnected && ble.characteristic != null) {
        try {
          await ble.characteristic!.write(data, withoutResponse: true);
        } catch (_) {}
      }
    }
  }

  /// Send a timer-update packet string to all connected devices.
  Future<void> sendPacket(String packet) async {
    final data = utf8.encode(packet);
    for (final ble in _connectedDevices) {
      if (ble.isConnected && ble.characteristic != null) {
        try {
          await ble.characteristic!.write(data, withoutResponse: true);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}
