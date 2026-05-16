import 'package:flutter/foundation.dart';

class GameState extends ChangeNotifier {
  // ── Game metadata ────────────────────────────────────────────────────────
  int period = 1;

  // ── Game timer (each digit stored separately, matching MIT App Inventor) ─
  // Default: 10:00.0  → Min1=1,Min2=0,Sec1=0,Sec2=0,mSec=0
  int min1 = 1;
  int min2 = 0;
  int sec1 = 0;
  int sec2 = 0;
  int mSec = 0;

  // ── Shot clock (default 24 → Shot1=2,Shot2=4) ───────────────────────────
  int shot1 = 2;
  int shot2 = 4;
  int mShot = 0;

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
  // Timer tick — called every 200 ms by TimerService
  // Replicates the MIT App Inventor nested if/else countdown exactly.
  // Returns true if state changed (so BleService knows to send a packet).
  // ─────────────────────────────────────────────────────────────────────────
  bool tickGameTimer() {
    if (!key) return false;
    bool changed = true;

    if (mSec > 0) {
      mSec -= 2;
    } else if (sec2 > 0) {
      sec2 -= 1;
      mSec = 8;
    } else if (sec1 > 0) {
      sec1 -= 1;
      mSec = 8;
      sec2 = 9;
    } else if (min2 > 0) {
      min2 -= 1;
      mSec = 8;
      sec2 = 9;
      sec1 = 5;
    } else if (min1 > 0) {
      min1 -= 1;
      mSec = 8;
      sec2 = 9;
      sec1 = 5;
      min2 = 9;
    } else {
      // Time expired
      hornx = 1;
      key = false;
      shotclockStatus = false;
      changed = true;
    }

    return changed;
  }

  bool tickShotClock() {
    if (!shotclockStatus) return false;

    if (mShot > 0) {
      mShot -= 2;
    } else if (shot2 > 0) {
      shot2 -= 1;
      mShot = 8;
    } else if (shot1 > 0) {
      shot1 -= 1;
      mShot = 8;
      shot2 = 9;
    } else {
      // Shot clock expired
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
  static const String timerPacketPrefix = '_'; // was '*' — MIT blocks show '_' prefix
  static const String timerPacketLineEnding = ''; // was '\n' — testing no terminator (fixed-length parse)
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

  void resetShotClock(int seconds) {
    // seconds is either 14 or 24
    if (seconds == 24) {
      shot1 = 2;
      shot2 = 4;
    } else {
      shot1 = 1;
      shot2 = 4;
    }
    mShot = 0;
    notifyListeners();
  }

  void triggerHorn() {
    hornx = hornx == 0 ? 1 : 0;
    notifyListeners();
  }

  void newGame() {
    key = false;
    shotclockStatus = false;
    min1 = 1;
    min2 = 0;
    sec1 = 0;
    sec2 = 0;
    mSec = 0;
    shot1 = 2;
    shot2 = 4;
    mShot = 0;
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
    min1 = 1;
    min2 = 0;
    sec1 = 0;
    sec2 = 0;
    mSec = 0;
    shot1 = 2;
    shot2 = 4;
    mShot = 0;
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

  // Called by TimerService after each tick to push UI update
  void tick() => notifyListeners();
}
