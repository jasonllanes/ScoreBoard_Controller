import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/commands.dart';
import '../models/game_state.dart';
import '../services/ble_service.dart';
import '../widgets/timer_display.dart';
import '../widgets/team_panel.dart';
import '../widgets/connection_bar.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  bool _showBoardLoading = false;

  // SC14/SC24: first tap just loads the value (doesn't start it); tapping
  // the SAME preset again — whenever that happens, no quick-double-tap
  // timing required — is what actually starts it counting down. Tapping a
  // different preset (or the same one a 3rd time) re-arms fresh instead of
  // starting, so it stays a predictable two-step pattern rather than a
  // hidden timing window.
  int? _armedShotClockSeconds;

  void _tapShotClockPreset(GameState gs, int seconds) {
    if (_armedShotClockSeconds == seconds) {
      _sendAndUpdate(() => gs.resetShotClock(seconds, start: true));
      setState(() => _armedShotClockSeconds = null);
    } else {
      _sendAndUpdate(() => gs.resetShotClock(seconds, start: false));
      setState(() => _armedShotClockSeconds = seconds);
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _send(int ascii) => context.read<BleService>().sendCommand(ascii);

  void _sendAndUpdate(void Function() mutation) {
    final gs = context.read<GameState>();
    mutation();
    final ble = context.read<BleService>();
    final packet = gs.buildPacket();
    if (gs.key) {
      // Clock is running — the 200ms tick loop resends the current state
      // every cycle, so a single send is enough; a burst here would just
      // queue up behind (and visibly race) the loop's own packets.
      ble.sendPacket(packet);
    } else {
      // Clock is stopped — nothing else will resend this, so guard against
      // a dropped write with a few repeats.
      ble.sendPacketReliable(packet);
    }
  }

  Future<void> _confirmNewGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112233),
        title: const Text('New Game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will reset all scores, fouls, and the timer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final gs = context.read<GameState>();
      final ble = context.read<BleService>();
      setState(() => _armedShotClockSeconds = null);
      gs.newGame();
      final packet = gs.buildPacket();
      debugPrint(
        '[PROTO] NEW GAME — sending 0x76 ("v") then reset packet "$packet"',
      );
      await ble.sendCommand(Cmd.newGame);
      await ble.sendPacketReliable(packet);
    }
  }

  void _guardedTap(VoidCallback ifStopped) {
    if (context.read<GameState>().key) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop clock to edit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ifStopped();
  }

  // ── Score edit (type a number instead of tapping +1/+2/-1 repeatedly) ──
  // The board has no "set score" command, only +1/-1 steps, so after the
  // app-side score is updated we walk the board to match by firing that
  // many single-byte step commands through BleService's serialized queue —
  // the same commands +1/-1 buttons already send, just automated.
  Future<void> _editTeamScore({
    required int current,
    required void Function(int) applyLocal,
    required int plusCmd,
    required int minusCmd,
    required String title,
  }) async {
    var text = '$current';

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112233),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextFormField(
          initialValue: text,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => text = v,
          decoration: const InputDecoration(
            labelText: 'Score',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, int.tryParse(text) ?? current),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;
    final target = result.clamp(0, 999);
    final delta = target - current;
    if (delta == 0) return;

    applyLocal(target);
    final ble = context.read<BleService>();
    final cmd = delta > 0 ? plusCmd : minusCmd;
    for (var i = 0; i < delta.abs(); i++) {
      ble.sendCommand(cmd);
    }
  }

  Future<void> _editGameTime() async {
    final gs = context.read<GameState>();
    final initMin = gs.min1 * 10 + gs.min2;
    final initSec = gs.sec1 * 10 + gs.sec2;

    // Values captured inside Navigator.pop — no controller to dispose after pop.
    var minText = '$initMin';
    var secText = '$initSec';

    final result = await showDialog<({int minutes, int seconds})>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112233),
        title: const Text(
          'Edit Game Time',
          style: TextStyle(color: Colors.white),
        ),
        content: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: minText,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => minText = v,
                decoration: const InputDecoration(
                  labelText: 'Min (0-99)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            Expanded(
              child: TextFormField(
                initialValue: secText,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => secText = v,
                decoration: const InputDecoration(
                  labelText: 'Sec (0-59)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, (
              minutes: int.tryParse(minText) ?? initMin,
              seconds: int.tryParse(secText) ?? initSec,
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;
    gs.setGameTime(minutes: result.minutes, seconds: result.seconds);
    context.read<BleService>().sendPacketReliable(gs.buildPacket());
  }

  Future<void> _editPeriod() async {
    final gs = context.read<GameState>();
    final chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112233),
        title: const Text('Set Quarter', style: TextStyle(color: Colors.white)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final q in [1, 2, 3, 4])
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gs.period == q
                      ? Colors.orange
                      : const Color(0xFF1E3050),
                ),
                onPressed: () => Navigator.pop(ctx, q),
                child: Text('Q$q'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted || chosen == null) return;
    gs.setPeriod(chosen);
  }

  Future<void> _editShotClock() async {
    final gs = context.read<GameState>();
    final initSec = gs.shot1 * 10 + gs.shot2;

    // StatefulBuilder owns the local state for quick-set buttons + text field.
    // Value is parsed and passed to Navigator.pop before dialog tears down.
    var secText = '$initSec';

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF112233),
          title: const Text(
            'Edit Shot Clock',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3050),
                    ),
                    onPressed: () => setState(() => secText = '24'),
                    child: const Text('24 sec'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3050),
                    ),
                    onPressed: () => setState(() => secText = '14'),
                    child: const Text('14 sec'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // key forces rebuild with new initialValue when quick buttons fire.
              TextFormField(
                key: ValueKey(secText),
                initialValue: secText,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => secText = v,
                decoration: const InputDecoration(
                  labelText: 'Custom (0-99 sec)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(secText) ?? initSec),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;
    gs.setShotClock(seconds: result);
    context.read<BleService>().sendPacketReliable(gs.buildPacket());
  }

  Future<void> _confirmNextQuarter() async {
    final gs = context.read<GameState>();
    if (gs.period >= 4) return;
    setState(() => _armedShotClockSeconds = null);
    context.read<GameState>().nextQuarter();
  }

  // ── Shared sections ───────────────────────────────────────────────────────

  /// START/STOP · HORN · SC14 · SC24 row
  Widget _controlRow(GameState gs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gs.key ? Colors.red : Colors.green,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final ok = gs.startStop(); // mutates key + notifyListeners
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Set a shot clock before starting'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                final isStart = gs.key; // already toggled
                final cmd = isStart ? Cmd.startClock : Cmd.stopClock;
                final ble = context.read<BleService>();
                final packet = gs.buildPacket();
                final ending = GameState.timerPacketLineEnding
                    .replaceAll('\r', '\\r')
                    .replaceAll('\n', '\\n');
                debugPrint(
                  '[PROTO] ${isStart ? "START" : "STOP"} — '
                  'prefix="${GameState.timerPacketPrefix}" '
                  'ending="$ending" '
                  'order=${GameState.timerCommandFirst ? "cmd→packet" : "packet→cmd"}',
                );
                if (GameState.timerCommandFirst) {
                  await ble.sendCommand(cmd);
                  await ble.sendPacket(packet);
                } else {
                  await ble.sendPacket(packet);
                  await ble.sendCommand(cmd);
                }
              },
              icon: Icon(gs.key ? Icons.pause : Icons.play_arrow, size: 18),
              label: Text(gs.key ? 'STOP' : 'START'),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gs.hornx == 1
                    ? Colors.amber
                    : const Color(0xFF1E3050),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                gs.triggerHorn();
                _send(gs.hornx == 1 ? Cmd.horn : Cmd.null_);
              },
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text('HORN'),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ShotClockPresetBtn(
              label: 'SC 14',
              armed: _armedShotClockSeconds == 14,
              onTap: () => _tapShotClockPreset(gs, 14),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ShotClockPresetBtn(
              label: 'SC 24',
              armed: _armedShotClockSeconds == 24,
              onTap: () => _tapShotClockPreset(gs, 24),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom action bar: arrows + Next QTR + New Game
  Widget _bottomBar(GameState gs) {
    return Container(
      color: const Color(0xFF0A0E1A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _BottomBtn(label: '◀ Left', onTap: () => _send(Cmd.leftArrow)),
          const SizedBox(width: 4),
          _BottomBtn(label: 'Right ▶', onTap: () => _send(Cmd.rightArrow)),
          const SizedBox(width: 4),
          _BottomBtn(
            label: 'Show Board',
            color: Colors.teal,
            loading: _showBoardLoading,
            onTap: _showBoardLoading
                ? null
                : () async {
                    // TimerService now resends the current packet every
                    // 200ms continuously, even while the clock is stopped
                    // (see timer_service.dart), so this no longer needs to
                    // manually burst/retry — any write that lands garbled
                    // while the board is still mid-transition self-corrects
                    // on its own within one more tick. Just send the
                    // trigger once; the loading spinner is purely cosmetic,
                    // covering the board's own transition time.
                    setState(() => _showBoardLoading = true);
                    try {
                      final ble = context.read<BleService>();
                      await ble.sendCommand(Cmd.showScoreboard);
                      await Future.delayed(const Duration(seconds: 3));
                    } finally {
                      if (mounted) setState(() => _showBoardLoading = false);
                    }
                  },
          ),
          const Spacer(),
          _BottomBtn(
            label: 'Next QTR',
            color: Colors.blueGrey,
            onTap: gs.period < 4 ? _confirmNextQuarter : null,
          ),
          const SizedBox(width: 4),
          _BottomBtn(
            label: 'New Game',
            color: Colors.deepOrange,
            onTap: _confirmNewGame,
          ),
        ],
      ),
    );
  }

  Widget _bleWarning() => Container(
    color: Colors.red.shade900,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: const Text(
      'No scoreboard connected — commands will not transmit',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white70, fontSize: 12),
    ),
  );

  // ── Team panel builders ───────────────────────────────────────────────────

  Widget _teamA(GameState gs) => TeamPanel(
    teamName: 'TEAM A',
    score: gs.teamAScore,
    fouls: gs.teamAFouls,
    tol: gs.teamATOL,
    accentColor: Colors.blue,
    onScoreTap: () => _editTeamScore(
      current: gs.teamAScore,
      applyLocal: gs.setTeamAScore,
      plusCmd: Cmd.teamBPlus1,
      minusCmd: Cmd.teamBMinus1,
      title: 'Edit Team A Score',
    ),
    onPlus1: () {
      gs.teamAScorePlus1();
      _send(Cmd.teamBPlus1);
    },
    onPlus2: () {
      gs.teamAScorePlus2();
      _send(Cmd.teamBPlus2);
    },
    onMinus1: () {
      gs.teamAScoreMinus1();
      _send(Cmd.teamBMinus1);
    },
    onFoulPlus: () {
      gs.teamAFoulPlus();
      _send(Cmd.teamBFoulPlus);
    },
    onFoulMinus: () {
      gs.teamAFoulMinus();
      _send(Cmd.teamBFoulMinus);
    },
    onTolMinus: () {
      gs.teamATOLMinus();
      _send(Cmd.teamBTolMinus);
    },
    onTolPlus: () {
      gs.teamATOLPlus();
      _send(Cmd.teamBTolPlus);
    },
  );

  Widget _teamB(GameState gs) => TeamPanel(
    teamName: 'TEAM B',
    score: gs.teamBScore,
    fouls: gs.teamBFouls,
    tol: gs.teamBTOL,
    accentColor: Colors.red,
    onScoreTap: () => _editTeamScore(
      current: gs.teamBScore,
      applyLocal: gs.setTeamBScore,
      plusCmd: Cmd.teamAPlus1,
      minusCmd: Cmd.teamAMinus1,
      title: 'Edit Team B Score',
    ),
    onPlus1: () {
      gs.teamBScorePlus1();
      _send(Cmd.teamAPlus1);
    },
    onPlus2: () {
      gs.teamBScorePlus2();
      _send(Cmd.teamAPlus2);
    },
    onMinus1: () {
      gs.teamBScoreMinus1();
      _send(Cmd.teamAMinus1);
    },
    onFoulPlus: () {
      gs.teamBFoulPlus();
      _send(Cmd.teamAFoulPlus);
    },
    onFoulMinus: () {
      gs.teamBFoulMinus();
      _send(Cmd.teamAFoulMinus);
    },
    onTolMinus: () {
      gs.teamBTOLMinus();
      _send(Cmd.teamATolMinus);
    },
    onTolPlus: () {
      gs.teamBTOLPlus();
      _send(Cmd.teamATolPlus);
    },
  );

  // ── Portrait layout ───────────────────────────────────────────────────────
  // Stack: ConnectionBar → TimerDisplay → Controls → [TeamA | TeamB] → Bottom
  Widget _portraitLayout(GameState gs, BleService ble) {
    return Column(
      children: [
        const ConnectionBar(),
        TimerDisplay(
          onGameTimeTap: () => _guardedTap(_editGameTime),
          onPeriodTap: () => _guardedTap(_editPeriod),
          onShotClockTap: () => _guardedTap(_editShotClock),
        ),
        _controlRow(gs),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _teamA(gs)),
              Expanded(child: _teamB(gs)),
            ],
          ),
        ),
        _bottomBar(gs),
        if (ble.connectionCount == 0) _bleWarning(),
      ],
    );
  }

  // ── Landscape layout ──────────────────────────────────────────────────────
  // Left column: Timer + Controls  |  Right column: TeamA + TeamB
  Widget _landscapeLayout(GameState gs, BleService ble) {
    return Column(
      children: [
        const ConnectionBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left — timer + controls
              Expanded(
                flex: 9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TimerDisplay(
                      onGameTimeTap: () => _guardedTap(_editGameTime),
                      onPeriodTap: () => _guardedTap(_editPeriod),
                      onShotClockTap: () => _guardedTap(_editShotClock),
                    ),
                    _controlRow(gs),
                  ],
                ),
              ),
              // Divider
              const VerticalDivider(
                color: Colors.white12,
                width: 1,
                thickness: 1,
              ),
              // Right — team panels
              Expanded(
                flex: 11,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _teamA(gs)),
                    Expanded(child: _teamB(gs)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _bottomBar(gs),
        if (ble.connectionCount == 0) _bleWarning(),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final ble = context.watch<BleService>();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: isLandscape
            ? _landscapeLayout(gs, ble)
            : _portraitLayout(gs, ble),
      ),
    );
  }
}

/// SC14/SC24 preset button: tap loads the value without starting it; the
/// caller tracks whether this preset is "armed" from a prior tap and turns
/// the *next* tap on it into the start action — see
/// _ScoreboardScreenState._tapShotClockPreset. `armed` just controls the
/// highlight so it's visually clear another tap will start it.
class _ShotClockPresetBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool armed;

  const _ShotClockPresetBtn({
    required this.label,
    required this.onTap,
    this.armed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: armed ? Colors.orange : const Color(0xFF1E3050),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool loading;

  const _BottomBtn({
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1E3050),
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: Size.zero,
        ),
        onPressed: null,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap == null ? Colors.grey : color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size.zero,
      ),
      onPressed: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
