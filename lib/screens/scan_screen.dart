import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import 'scoreboard_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleService>().startScan();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
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
      body: Column(
        children: [
          // ── Scan control bar ──────────────────────────────────────────────
          Container(
            color: const Color(0xFF112233),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ble.isScanning
                        ? 'Scanning for devices…'
                        : '${ble.scanResults.length} device(s) found',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                if (ble.isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => ble.startScan(),
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    label: const Text(
                      'Scan Again',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),

          // ── Connected devices ─────────────────────────────────────────────
          if (ble.connectedDevices.isNotEmpty) ...[
            const _SectionHeader(title: 'Connected'),
            ...ble.connectedDevices.map((d) => _ConnectedTile(bleDevice: d)),
          ],

          // ── Scan results ──────────────────────────────────────────────────
          if (ble.scanResults.isNotEmpty) ...[
            const _SectionHeader(title: 'Available Devices'),
            Expanded(
              child: ListView.builder(
                itemCount: ble.scanResults.length,
                itemBuilder: (context, i) {
                  final result = ble.scanResults[i];
                  final name = result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : result.device.remoteId.str;
                  final alreadyConnected = ble.connectedDevices.any(
                    (d) => d.device.remoteId == result.device.remoteId,
                  );

                  return ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.orange),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${result.device.remoteId.str}  RSSI: ${result.rssi} dBm',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: alreadyConnected
                        ? const Chip(
                            label: Text(
                              'Connected',
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.green,
                          )
                        : ble.connectionCount >= 4
                        ? const Chip(
                            label: Text(
                              'Slots full',
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.grey,
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            onPressed: () => ble.connect(result.device),
                            child: const Text('Connect'),
                          ),
                  );
                },
              ),
            ),
          ] else if (!ble.isScanning) ...[
            const Expanded(
              child: Center(
                child: Text(
                  'No devices found.\nTap Scan Again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ] else
            const Expanded(child: SizedBox.shrink()),
        ],
      ),

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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D1B2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ConnectedTile extends StatelessWidget {
  final BleDevice bleDevice;
  const _ConnectedTile({required this.bleDevice});
  @override
  Widget build(BuildContext context) {
    final ble = context.read<BleService>();
    return ListTile(
      leading: const Icon(Icons.bluetooth_connected, color: Colors.greenAccent),
      title: Text(bleDevice.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        bleDevice.device.remoteId.str,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The 3 boards look identical over BLE (same name), and the main
          // board vs. shot clock boards parse the timer packet differently
          // — tag each device's role so BleService knows which packet
          // shape to send it.
          DropdownButton<BleRole>(
            value: bleDevice.role,
            dropdownColor: const Color(0xFF112233),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: BleRole.unknown, child: Text('Role?')),
              DropdownMenuItem(
                value: BleRole.mainBoard,
                child: Text('Main Board'),
              ),
              DropdownMenuItem(
                value: BleRole.shotClock,
                child: Text('Shot Clock'),
              ),
            ],
            onChanged: (role) {
              if (role != null) ble.setRole(bleDevice.device, role);
            },
          ),
          TextButton(
            onPressed: () => ble.disconnect(bleDevice.device),
            child: const Text(
              'Disconnect',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
