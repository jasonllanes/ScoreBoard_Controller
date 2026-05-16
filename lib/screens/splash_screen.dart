import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Requesting permissions…';
  bool _allGranted = false;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final List<Permission> permissions;

    if (Platform.isAndroid) {
      // Android 12+ needs BLUETOOTH_SCAN + BLUETOOTH_CONNECT.
      // Older Android needs location for BLE scanning.
      permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
    } else {
      permissions = [Permission.bluetooth, Permission.locationWhenInUse];
    }

    final statuses = await permissions.request();

    bool allOk = true;
    bool anyPermanent = false;

    for (final entry in statuses.entries) {
      if (!entry.value.isGranted) {
        allOk = false;
        if (entry.value.isPermanentlyDenied) anyPermanent = true;
      }
    }

    setState(() {
      _allGranted = allOk;
      _permanentlyDenied = anyPermanent;
      if (allOk) {
        _statusMessage = 'All permissions granted!';
      } else if (anyPermanent) {
        _statusMessage =
            'Some permissions were permanently denied.\nPlease enable them in App Settings.';
      } else {
        _statusMessage =
            'Permissions required to use Bluetooth.\nPlease grant them.';
      }
    });

    if (allOk) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sports_basketball,
                  color: Colors.orange,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scoreboard Controller',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                if (!_allGranted) ...[
                  const CircularProgressIndicator(color: Colors.orange),
                  const SizedBox(height: 24),
                ],
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                if (_permanentlyDenied) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: openAppSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Open App Settings'),
                  ),
                ],
                if (!_allGranted && !_permanentlyDenied) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Grant Permissions'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
