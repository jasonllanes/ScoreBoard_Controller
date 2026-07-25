/// BLE command byte constants — mirrors the Java CMD_* / COMMAND_* constants
/// exactly. Each value is the ASCII code of the corresponding character.
abstract final class Cmd {
  // ── General ──────────────────────────────────────────────────────────────
  static const int null_ = 0x2D; // '-'  null / no-op
  // Shares byte '_' (0x5F) with GameState.timerPacketPrefix; Arduino tells them
  // apart by length (lone byte = horn, full packet = timer). Keep in sync.
  static const int horn = 0x5F; // '_'  gametime + shotclock + horn
  static const int newGame = 0x76; // 'v'  new game

  // ── Clock control ────────────────────────────────────────────────────────
  static const int startClock = 0x73; // 's'  start game clock
  static const int stopClock = 0x74; // 't'  stop  game clock
  static const int resetClock = 0x75; // 'u'  reset game clock
  // Transitions the board from its idle/placeholder screen to the live
  // scoreboard display. Same byte value as the old unused "start shot
  // clock" legacy command ('x') — repurposed since nothing else uses it.
  static const int showScoreboard = 0x78; // 'x'  show scoreboard display
  static const int stopShotClock = 0x79; // 'y'  stop  shot clock
  static const int resetShotClock = 0x7A; // 'z'  reset shot clock
  static const int shotClock14 = 0x71; // 'q'  set shot clock → 14
  static const int shotClock24 = 0x72; // 'r'  set shot clock → 24

  // ── Team A ───────────────────────────────────────────────────────────────
  static const int teamAPlus1 = 0x6A; // 'j'  score +1
  static const int teamAPlus2 = 0x6B; // 'k'  score +2
  static const int teamAMinus1 = 0x6D; // 'm'  score -1
  static const int teamAFoulPlus = 0x6C; // 'l'  foul  +1
  static const int teamAFoulMinus = 0x43; // 'C'  foul  -1
  static const int teamATolMinus = 0x6E; // 'n'  TOL   -1
  static const int teamATolPlus = 0x44; // 'D'  TOL   +1

  // ── Team B ───────────────────────────────────────────────────────────────
  static const int teamBPlus1 = 0x61; // 'a'  score +1
  static const int teamBPlus2 = 0x62; // 'b'  score +2
  static const int teamBMinus1 = 0x64; // 'd'  score -1
  static const int teamBFoulPlus = 0x63; // 'c'  foul  +1
  static const int teamBFoulMinus = 0x41; // 'A'  foul  -1
  static const int teamBTolMinus = 0x65; // 'e'  TOL   -1
  static const int teamBTolPlus = 0x42; // 'B'  TOL   +1

  // ── Arrows ───────────────────────────────────────────────────────────────
  static const int rightArrow = 0x57; // 'W'  right arrow
  static const int leftArrow = 0x56; // 'V'  left  arrow
}
