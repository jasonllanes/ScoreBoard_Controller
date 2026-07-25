import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/game_state.dart';
import 'services/ble_service.dart';
import 'services/timer_service.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow both portrait and landscape — layout adapts via OrientationBuilder
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ScoreboardApp());
}

class ScoreboardApp extends StatelessWidget {
  const ScoreboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        ChangeNotifierProvider(create: (_) => BleService()),
        // Singleton, started once at app launch — each ScoreboardScreen
        // used to create its own TimerService, so a double-tap on "Go to
        // Scoreboard" could push two screens and end up with two timers
        // both ticking the same GameState, running the clock at 2x speed.
        // lazy: false — Provider only runs `create` the first time
        // something reads it, and nothing in the widget tree needs to hold
        // a TimerService reference (it works purely by mutating the
        // already-shared GameState). Without this, `create`/`.start()`
        // would never actually run and the clock just wouldn't tick.
        Provider<TimerService>(
          lazy: false,
          create: (context) => TimerService(
            gameState: context.read<GameState>(),
            bleService: context.read<BleService>(),
          )..start(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Scoreboard Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.orange,
            secondary: Colors.orangeAccent,
          ),
          scaffoldBackgroundColor: const Color(0xFF0D1B2A),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
