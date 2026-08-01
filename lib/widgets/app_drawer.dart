import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/scoreboard_screen.dart';
import '../screens/settings_screen.dart';

/// Shared nav drawer — Scoreboard Controller / Settings up top, Logout
/// below a divider. Used from both ScanScreen and ScoreboardScreen so
/// Settings/Logout are reachable from anywhere in the app.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1B2A),
      child: SafeArea(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF112233)),
              child: Row(
                children: [
                  Icon(Icons.sports_basketball, color: Colors.orange, size: 36),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scoreboard Controller',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.scoreboard, color: Colors.white70),
              title: const Text(
                'Scoreboard Controller',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop(); // close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScoreboardScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.of(context).pop();
                // AuthGate's onAuthStateChange listener swaps back to
                // LoginScreen automatically once the session clears.
                Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
