import 'dart:async';
import '../models/game_state.dart';
import 'ble_service.dart';

/// Drives the 200 ms countdown tick, mirrors MIT App Inventor Clock1.Timer.
/// On each tick:
///   1. Advance game timer (if running)
///   2. Advance shot clock (if running)
///   3. Send BLE packet to all connected Arduino scoreboards
class TimerService {
  final GameState gameState;
  final BleService bleService;

  Timer? _timer;
  static const _interval = Duration(milliseconds: 200);

  TimerService({required this.gameState, required this.bleService});

  bool get isRunning => _timer != null && _timer!.isActive;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, _onTick);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick(Timer _) {
    bool timerChanged = gameState.tickGameTimer();
    bool shotChanged = gameState.tickShotClock();

    if (timerChanged || shotChanged) {
      gameState.tick(); // notifies UI
      bleService.sendPacket(gameState.buildPacket()); // send to Arduino(s)
    }
  }

  void dispose() {
    stop();
  }
}
