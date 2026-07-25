import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The main board and shot clock boards parse the timer packet differently:
// the main board skips the leading prefix byte before reading digits, but
// the shot clock boards' firmware doesn't — it reads all 10 digit fields
// starting right from byte 0, which shifts every field one position early
// (e.g. "10:00"/"24" comes out as "01:00"/"02"). Since all 3 peripherals
// are otherwise indistinguishable (same advertised name), the role is
// tagged manually per connected device from the scan screen.
enum BleRole { unknown, mainBoard, shotClock }

class BleDevice {
  final BluetoothDevice device;
  BluetoothCharacteristic? characteristic;
  bool isConnecting = false;
  bool isConnected = false;
  BleRole role = BleRole.unknown;

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

      // Same advertised name for all 3 boards, but MAC address is stable
      // per physical unit — restore whichever role was tagged for this MAC
      // last time so it doesn't need to be re-tagged every session. This
      // is best-effort and must never be able to undo a connection that
      // already succeeded, so any failure here just leaves the role
      // unknown instead of propagating.
      try {
        ble.role = await _loadRole(device.remoteId.str);
        notifyListeners();
      } catch (e) {
        debugPrint('[BLE] ⚠ role restore failed for ${ble.name}: $e');
      }
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

  static const String _rolePrefKeyPrefix = 'ble_role_';

  Future<void> setRole(BluetoothDevice device, BleRole role) async {
    for (final ble in _connectedDevices) {
      if (ble.device.remoteId == device.remoteId) {
        ble.role = role;
        break;
      }
    }
    notifyListeners();

    // Persisting is a nice-to-have — a failure here shouldn't undo the
    // in-memory role assignment that was just applied above.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_rolePrefKeyPrefix${device.remoteId.str}', role.name);
    } catch (e) {
      debugPrint('[BLE] ⚠ role save failed for ${device.remoteId}: $e');
    }
  }

  Future<BleRole> _loadRole(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_rolePrefKeyPrefix$macAddress');
    return BleRole.values.firstWhere(
      (r) => r.name == stored,
      orElse: () => BleRole.unknown,
    );
  }

  // ── Data sending ─────────────────────────────────────────────────────────
  //
  // All writes (single-byte commands AND timer packets) go through _enqueue
  // so only one is ever in flight at a time, with a minimum gap enforced
  // between them. Serializing alone isn't enough: `write(withoutResponse:
  // true)` can resolve almost as soon as the OS accepts the write, so two
  // queued writes can still leave the BLE stack back-to-back with no real
  // gap. The Arduino just reads a raw fixed-length byte stream with no
  // framing, so if a command byte (e.g. a score tap) lands right against a
  // timer packet from the 200ms loop, its receive buffer can merge the two
  // and the game time / shot clock digits come out garbled — even though
  // the score command itself never touches that state.
  Future<void> _writeQueue = Future.value();
  DateTime? _lastWriteAt;
  static const _minWriteGap = Duration(milliseconds: 60);

  Future<void> _enqueue(Future<void> Function() op) {
    final result = _writeQueue.then((_) async {
      final lastWrite = _lastWriteAt;
      if (lastWrite != null) {
        final wait = _minWriteGap - DateTime.now().difference(lastWrite);
        if (wait > Duration.zero) await Future.delayed(wait);
      }
      await op();
      _lastWriteAt = DateTime.now();
    });
    _writeQueue = result.catchError((_) {});
    return result;
  }

  /// Send a single ASCII command byte (button press) to all connected devices.
  Future<void> sendCommand(int asciiCode) => _enqueue(() => _writeCommand(asciiCode));

  Future<void> _writeCommand(int asciiCode) async {
    final char = String.fromCharCode(asciiCode);
    debugPrint('[BLE] sendCommand: 0x${asciiCode.toRadixString(16).toUpperCase()} ("$char") — '
        '${_connectedDevices.length} device(s)');
    final data = [asciiCode];
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
  }

  /// Send a timer-update packet several times in quick succession.
  ///
  /// `write(withoutResponse: true)` gives no delivery confirmation, and the
  /// continuous 200ms tick loop only resends while the clock is running —
  /// so a one-off packet (New Game, edit time/shot clock) that gets dropped
  /// leaves the board showing stale/garbled digits with nothing to correct
  /// it. Repeating the write a few times makes that far less likely.
  Future<void> sendPacketReliable(
    String packet, {
    int times = 3,
    Duration gap = const Duration(milliseconds: 80),
  }) async {
    for (var i = 0; i < times; i++) {
      await sendPacket(packet);
      if (i < times - 1) await Future.delayed(gap);
    }
  }

  // Coalescing: if a burst of packets arrives faster than the queue can
  // drain them (e.g. a few stale 200ms-tick packets still waiting right as
  // New Game resets state), only the *latest* one actually matters for
  // display. Sending every stale one in order would visibly flicker
  // through old values before landing on the current state, so skip
  // straight to whatever's newest once a write slot frees up.
  String? _latestPacket;
  bool _packetWorkerRunning = false;

  /// Send a timer-update packet string to all connected devices.
  Future<void> sendPacket(String packet) async {
    _latestPacket = packet;
    if (_packetWorkerRunning) return;
    _packetWorkerRunning = true;
    try {
      while (_latestPacket != null) {
        // Pick which packet to send at the last possible moment — inside
        // the enqueued closure, right before the physical write — instead
        // of when it was first scheduled. If something newer arrived while
        // this slot was waiting out the write-queue's spacing delay, send
        // that instead of the value that was current back when we started
        // waiting for a turn.
        await _enqueue(() {
          final toSend = _latestPacket;
          _latestPacket = null;
          return toSend == null ? Future.value() : _writePacket(toSend);
        });
      }
    } finally {
      _packetWorkerRunning = false;
    }
  }

  Future<void> _writePacket(String packet) async {
    final escaped = packet.replaceAll('\r', '\\r').replaceAll('\n', '\\n');
    debugPrint('[BLE] sendPacket: "$escaped" — ${_connectedDevices.length} device(s)');
    // Broadcast the identical packet to every connected board — the main
    // board and both shot clocks all parse it the same way. (Previously
    // tried sending the shot clocks a prefix-stripped variant based on a
    // theory that turned out wrong and regressed the main board instead;
    // reverted.)
    final data = utf8.encode(packet);
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
