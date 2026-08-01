import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/app_settings_service.dart';
import '../widgets/ble_connect_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pickingLogo = false;

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;
      await context.read<AppSettingsService>().setLogo(File(picked.path));
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF112233),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          // ── Logo ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'LOGO',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF112233),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: settings.hasLogo
                      ? Image.file(File(settings.logoPath!), fit: BoxFit.cover)
                      : const Icon(Icons.image, color: Colors.white24, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.hasLogo ? 'Logo set' : 'No logo uploaded',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Shown on the scoreboard controller screen.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            onPressed: _pickingLogo ? null : _pickLogo,
                            child: _pickingLogo
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(settings.hasLogo ? 'Change' : 'Upload'),
                          ),
                          if (settings.hasLogo) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () =>
                                  context.read<AppSettingsService>().clearLogo(),
                              child: const Text(
                                'Remove',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Divider(color: Colors.white24, height: 1),
          ),

          // ── Bluetooth ────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'BLUETOOTH DEVICES',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Connect here once — the connection stays active when you go '
              'to Scoreboard Controller, no need to reconnect there.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          const BleConnectPanel(),
        ],
      ),
    );
  }
}
