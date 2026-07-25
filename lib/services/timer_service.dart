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
  DateTime? _lastTick;
  static const _interval = Duration(milliseconds: 200);

  TimerService({required this.gameState, required this.bleService});

  bool get isRunning => _timer != null && _timer!.isActive;

  void start() {
    _timer?.cancel();
    _lastTick = DateTime.now();
    _timer = Timer.periodic(_interval, _onTick);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick(Timer _) {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastTick!).inMilliseconds;
    _lastTick = now;

    // Use the real elapsed wall-clock time rather than assuming the
    // interval fired exactly on schedule, so the countdown stays in sync
    // with the device's actual clock even if a callback runs late.
    bool timerChanged = gameState.tickGameTimer(elapsedMs);
    bool shotChanged = gameState.tickShotClock(elapsedMs);

    if (timerChanged || shotChanged) {
      gameState.tick(); // notifies UI
    }

    // Always resend, even when nothing changed (clock stopped/idle). This
    // is what makes the packet stream self-correcting: a single write that
    // lands garbled or gets dropped — e.g. right after "Show Board" while
    // the board is still finishing its idle→live transition — heals
    // itself within one more 200ms tick instead of staying stuck showing
    // garbage until something else happens to trigger another send.
    bleService.sendPacket(gameState.buildPacket());
  }

  void dispose() {
    stop();
  }
}
