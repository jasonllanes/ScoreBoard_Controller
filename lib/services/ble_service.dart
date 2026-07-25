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
  static const String _shortServiceUuid = 'ffe0';
  static const String _characteristicUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const String _shortCharacteristicUuid = 'ffe1';
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

      debugPrint('[BLE] GATT discovery for ${ble.name} (${device.remoteId}): ${services.length} service(s)');

      for (final svc in services) {
        final svcUuid = svc.uuid.toString().toLowerCase();
        final isTarget = _matchesUuid(svcUuid, _serviceUuid, _shortServiceUuid);
        debugPrint('[BLE]   service: $svcUuid${isTarget ? " ← TARGET" : ""}');

        BluetoothCharacteristic? exact;
        BluetoothCharacteristic? fallback;

        for (final ch in svc.characteristics) {
          final chUuid = ch.uuid.toString().toLowerCase();
          final props = _describeProperties(ch.properties);
          final isCharTarget =
              isTarget && _matchesUuid(chUuid, _characteristicUuid, _shortCharacteristicUuid);
          debugPrint('[BLE]     char: $chUuid [$props]${isCharTarget ? " ← WANT" : ""}');

          if (isTarget) {
            if (isCharTarget) {
              exact = ch;
            } else if (fallback == null &&
                (ch.properties.write || ch.properties.writeWithoutResponse)) {
              fallback = ch;
            }
          }
        }

        if (isTarget) {
          ble.characteristic = exact ?? fallback;
          if (ble.characteristic != null) {
            debugPrint('[BLE]   → SELECTED: ${ble.characteristic!.uuid} '
                '(${exact != null ? "exact ffe1" : "fallback — ffe1 not matched, using first writable"})');
            break;
          }
          debugPrint('[BLE]   → target service found but NO writable characteristic');
        }
      }

      ble.isConnecting = false;

      if (ble.characteristic == null) {
        debugPrint('[BLE] ✗ No writable characteristic found for ${ble.name} — disconnecting');
        _connectedDevices.remove(ble);
        await device.disconnect();
        notifyListeners();
        return;
      }

      ble.isConnected = true;
      debugPrint('[BLE] ✓ ${ble.name} ready — char: ${ble.characteristic!.uuid}');

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevices.removeWhere(
            (d) => d.device.remoteId == device.remoteId,
          );
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[BLE] ✗ connect error for ${ble.name}: $e');
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

  // HM-10 class modules coalesce writes issued a few ms apart into one chunk.
  // A command byte glued onto the front of a timer packet shifts the Arduino's
  // fixed-offset parse by one byte (10:00 shown as 01:00), so writes are
  // serialised and spaced. Raise the gap if a board still merges them.
  static const Duration writeGap = Duration(milliseconds: 40);
  Future<void> _writeQueue = Future<void>.value();
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  /// Queues a write so it never shares a BLE chunk with the previous one.
  Future<void> _enqueueWrite(List<int> data) {
    _writeQueue = _writeQueue.then((_) => _writeSpaced(data));
    return _writeQueue;
  }

  Future<void> _writeSpaced(List<int> data) async {
    final elapsed = DateTime.now().difference(_lastWrite);
    if (elapsed < writeGap) {
      await Future<void>.delayed(writeGap - elapsed);
    }
    for (final ble in _connectedDevices) {
      debugPrint('[BLE]   → ${ble.name} (${ble.device.remoteId}) '
          'characteristic=${ble.characteristic != null ? "present" : "NULL"}');
      if (ble.isConnected && ble.characteristic != null) {
        try {
          await ble.characteristic!.write(data, withoutResponse: true);
          debugPrint('[BLE]   ✓ write OK');
        } catch (e) {
          debugPrint('[BLE]   ✗ write FAILED: $e');
        }
      }
    }
    _lastWrite = DateTime.now();
  }

  /// Send a single ASCII command byte (button press) to all connected devices.
  Future<void> sendCommand(int asciiCode) {
    final char = String.fromCharCode(asciiCode);
    debugPrint('[BLE] sendCommand: 0x${asciiCode.toRadixString(16).toUpperCase()} ("$char") — '
        '${_connectedDevices.length} device(s)');
    return _enqueueWrite([asciiCode]);
  }

  /// Send a timer-update packet string to all connected devices.
  Future<void> sendPacket(String packet) {
    final escaped = packet.replaceAll('\r', '\\r').replaceAll('\n', '\\n');
    debugPrint('[BLE] sendPacket: "$escaped" — ${_connectedDevices.length} device(s)');
    return _enqueueWrite(utf8.encode(packet));
  }

  // Accepts both full 128-bit UUID and short 16-bit UUID forms.
  static bool _matchesUuid(String uuid, String full, String short) {
    final u = uuid.toLowerCase();
    return u == full.toLowerCase() || u == short.toLowerCase();
  }

  static String _describeProperties(CharacteristicProperties p) {
    final parts = <String>[];
    if (p.read) parts.add('read');
    if (p.write) parts.add('write');
    if (p.writeWithoutResponse) parts.add('writeWithoutResponse');
    if (p.notify) parts.add('notify');
    if (p.indicate) parts.add('indicate');
    return parts.isEmpty ? 'none' : parts.join(', ');
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}
