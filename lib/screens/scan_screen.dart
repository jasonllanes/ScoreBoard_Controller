import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ble_connect_panel.dart';
import 'scoreboard_screen.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF112233),
        title: const Text(
          'Find Scoreboard Devices',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // Connection slot indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(4, (i) {
                final connected = i < ble.connectionCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    Icons.bluetooth,
                    color: connected ? Colors.greenAccent : Colors.white24,
                    size: 20,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      body: const SingleChildScrollView(child: BleConnectPanel()),

      // ── Go to scoreboard ──────────────────────────────────────────────────
      bottomNavigationBar: ble.connectionCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ScoreboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.scoreboard),
                  label: Text(
                    'Go to Scoreboard  (${ble.connectionCount}/4 connected)',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
