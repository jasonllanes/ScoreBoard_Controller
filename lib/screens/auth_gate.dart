import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

/// Gates the whole app behind a Supabase session. Listens to
/// onAuthStateChange rather than checking currentSession once, so signing
/// in/out swaps screens immediately without any manual navigation calls
/// from LoginScreen or elsewhere.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        return session != null ? const SplashScreen() : const LoginScreen();
      },
    );
  }
}
