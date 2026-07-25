import 'package:flutter/foundation.dart';

class GameState extends ChangeNotifier {
  // ── Game metadata ────────────────────────────────────────────────────────
  int period = 1;

  // ── Game timer ────────────────────────────────────────────────────────────
  // Stored as real milliseconds remaining (default 10:00) and ticked forward
  // by actual elapsed wall-clock time (see tickGameTimer), so the countdown
  // always matches the phone's real clock instead of drifting when a
  // Timer.periodic callback fires late.
  static const int _defaultGameMs = 10 * 60 * 1000;
  static const int _defaultShotMs = 24 * 1000;

  int _gameTimeMs = _defaultGameMs;
  int _shotClockMs = _defaultShotMs;

  // Digits derived from _gameTimeMs / _shotClockMs — same field names/shape
  // as before (min1/min2/sec1/sec2/mSec, shot1/shot2/mShot) so buildPacket()
  // and the UI widgets are unaffected.
  int get min1 => (_gameTimeMs ~/ 60000) ~/ 10;
  int get min2 => (_gameTimeMs ~/ 60000) % 10;
  int get sec1 => ((_gameTimeMs ~/ 1000) % 60) ~/ 10;
  int get sec2 => ((_gameTimeMs ~/ 1000) % 60) % 10;
  int get mSec => (_gameTimeMs % 1000) ~/ 100;

  int get shot1 => (_shotClockMs ~/ 1000) ~/ 10;
  int get shot2 => (_shotClockMs ~/ 1000) % 10;
  int get mShot => (_shotClockMs % 1000) ~/ 100;

  // ── Control flags ────────────────────────────────────────────────────────
  bool key = false; // game timer running
  bool shotclockStatus = false; // shot clock running
  int hornx = 0; // 0=no horn, 1=horn triggered

  // ── Scores, fouls, timeouts ──────────────────────────────────────────────
  int teamAScore = 0;
  int teamBScore = 0;
  int teamAFouls = 0;
  int teamBFouls = 0;
  int teamATOL = 5;
  int teamBTOL = 5;

  // ─────────────────────────────────────────────────────────────────────────
  // Timer tick — called by TimerService with the *actual* elapsed wall-clock
  // milliseconds since the last tick (measured via DateTime.now()), so the
  // countdown tracks the phone's real clock instead of assuming a fixed
  // interval per callback. Returns true if state changed (so BleService
  // knows to send a packet).
  // ─────────────────────────────────────────────────────────────────────────
  bool tickGameTimer(int elapsedMs) {
    if (!key) return false;

    _gameTimeMs -= elapsedMs;
    if (_gameTimeMs <= 0) {
      _gameTimeMs = 0;
      hornx = 1;
      key = false;
      shotclockStatus = false;
    }

    return true;
  }

  bool tickShotClock(int elapsedMs) {
    if (!shotclockStatus) return false;

    _shotClockMs -= elapsedMs;
    if (_shotClockMs <= 0) {
      _shotClockMs = 0;
      hornx = 1;
      shotclockStatus = false;
    }

    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLE packet — mirrors the MIT App Inventor join block:
  // separator + Min1 + Min2 + Sec1 + Sec2 + mSec +
  //             Shot1 + Shot2 + mShot + Hornx + Min1
  //
  // ── Timer protocol test config ────────────────────────────────────────────
  // Change these constants to test protocol variants without refactoring.
  //
  // timerPacketPrefix:   '*' (PDF) or '_' (original — collides with Cmd.horn)
  // timerPacketLineEnding: '' | '\n' | '\r\n' — Arduino may need newline
  // timerCommandFirst:   true  = send 's'/'t' BEFORE packet
  //                      false = send packet BEFORE 's'/'t'
  // ─────────────────────────────────────────────────────────────────────────
  // NOTE: '_' (0x5F) is also Cmd.horn. Safe because the Arduino disambiguates by
  // length: a lone '_' byte = horn, a full '_'-prefixed packet = timer update.
  // CONFIRMED WORKING on physical hardware — do not change without testing
  // on the actual Arduino board first (the '*' from the PDF broke sync).
  static const String timerPacketPrefix = '_';
  static const String timerPacketLineEnding =
      ''; // was '\n' — testing no terminator (fixed-length parse)
  static const bool timerCommandFirst = true;

  String buildPacket() {
    return '$timerPacketPrefix$min1$min2$sec1$sec2$mSec$shot1$shot2$mShot$hornx$min1$timerPacketLineEnding';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // State mutations (called from UI — each calls notifyListeners)
  // ─────────────────────────────────────────────────────────────────────────

  void startStop() {
    key = !key;
    if (key) {
      hornx = 0;
      shotclockStatus = true;
    } else {
      shotclockStatus = false;
    }
    notifyListeners();
  }

  void resetShotClock(int seconds, {required bool start}) {
    // seconds is either 14 or 24. A single tap just loads the value
    // (start: false); a double tap loads it and starts it counting down
    // (start: true) — independent of whether the game clock is running.
    _shotClockMs = seconds * 1000;
    shotclockStatus = start;
    if (hornx == 1) hornx = 0;
    notifyListeners();
  }

  void triggerHorn() {
    hornx = hornx == 0 ? 1 : 0;
    notifyListeners();
  }

  void newGame() {
    key = false;
    shotclockStatus = false;
    _gameTimeMs = _defaultGameMs;
    _shotClockMs = _defaultShotMs;
    hornx = 0;
    teamAScore = 0;
    teamBScore = 0;
    teamAFouls = 0;
    teamBFouls = 0;
    teamATOL = 5;
    teamBTOL = 5;
    period = 1;
    notifyListeners();
  }

  void nextQuarter() {
    period = (period < 4) ? period + 1 : period;
    key = false;
    shotclockStatus = false;
    _gameTimeMs = _defaultGameMs;
    _shotClockMs = _defaultShotMs;
    hornx = 0;
    notifyListeners();
  }

  // ── Team A ───────────────────────────────────────────────────────────────
  void teamAScorePlus1() {
    teamAScore++;
    notifyListeners();
  }

  void teamAScorePlus2() {
    teamAScore += 2;
    notifyListeners();
  }

  void teamAScoreMinus1() {
    if (teamAScore > 0) teamAScore--;
    notifyListeners();
  }

  // Direct edit (e.g. from a "tap score to type a number" dialog). The
  // board has no "set score" command, only +1/-1 steps — the caller is
  // responsible for sending the matching number of step commands to keep
  // the physical board in sync with this value.
  void setTeamAScore(int score) {
    teamAScore = score.clamp(0, 999);
    notifyListeners();
  }

  void teamAFoulPlus() {
    teamAFouls++;
    notifyListeners();
  }

  void teamAFoulMinus() {
    if (teamAFouls > 0) teamAFouls--;
    notifyListeners();
  }

  void teamATOLMinus() {
    if (teamATOL > 0) teamATOL--;
    notifyListeners();
  }

  void teamATOLPlus() {
    teamATOL++;
    notifyListeners();
  }

  // ── Team B ───────────────────────────────────────────────────────────────
  void teamBScorePlus1() {
    teamBScore++;
    notifyListeners();
  }

  void teamBScorePlus2() {
    teamBScore += 2;
    notifyListeners();
  }

  void teamBScoreMinus1() {
    if (teamBScore > 0) teamBScore--;
    notifyListeners();
  }

  void setTeamBScore(int score) {
    teamBScore = score.clamp(0, 999);
    notifyListeners();
  }

  void teamBFoulPlus() {
    teamBFouls++;
    notifyListeners();
  }

  void teamBFoulMinus() {
    if (teamBFouls > 0) teamBFouls--;
    notifyListeners();
  }

  void teamBTOLMinus() {
    if (teamBTOL > 0) teamBTOL--;
    notifyListeners();
  }

  void teamBTOLPlus() {
    teamBTOL++;
    notifyListeners();
  }

  // ── Edit setters (only call when clock is stopped) ──────────────────────
  void setGameTime({required int minutes, required int seconds}) {
    final m = minutes.clamp(0, 99);
    final s = seconds.clamp(0, 59);
    _gameTimeMs = (m * 60 + s) * 1000;
    notifyListeners();
  }

  void setShotClock({required int seconds}) {
    final s = seconds.clamp(0, 99);
    _shotClockMs = s * 1000;
    notifyListeners();
  }

  void setPeriod(int p) {
    period = p.clamp(1, 4);
    notifyListeners();
  }

  // Called by TimerService after each tick to push UI update
  void tick() => notifyListeners();
}
