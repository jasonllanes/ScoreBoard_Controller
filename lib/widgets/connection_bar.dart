import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_settings_service.dart';
import '../services/ble_service.dart';
import '../screens/scan_screen.dart';

/// Top bar showing connection status. Tap to navigate back to scan screen.
class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final settings = context.watch<AppSettingsService>();

    return Container(
      color: const Color(0xFF112233),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70, size: 20),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          if (settings.hasLogo) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white10,
              backgroundImage: FileImage(File(settings.logoPath!)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.bluetooth, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${ble.connectionCount}/4 scoreboard(s) connected',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  ...List.generate(4, (i) {
                    final connected = i < ble.connectionCount;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: connected ? Colors.greenAccent : Colors.white24,
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
