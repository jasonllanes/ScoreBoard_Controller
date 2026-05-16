import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/commands.dart';
import '../models/game_state.dart';
import '../services/ble_service.dart';
import '../services/timer_service.dart';
import '../widgets/timer_display.dart';
import '../widgets/team_panel.dart';
import '../widgets/connection_bar.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late TimerService _timerService;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _timerService = TimerService(
      gameState: context.read<GameState>(),
      bleService: context.read<BleService>(),
    );
    _timerService.start();
  }

  @override
  void dispose() {
    _timerService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _send(int ascii) => context.read<BleService>().sendCommand(ascii);

  void _sendAndUpdate(void Function() mutation) {
    mutation();
    context.read<BleService>().sendPacket(
      context.read<GameState>().buildPacket(),
    );
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
      context.read<GameState>().newGame();
      _send(Cmd.newGame);
    }
  }

  Future<void> _confirmNextQuarter() async {
    final gs = context.read<GameState>();
    if (gs.period >= 4) return;
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
              onPressed: () {
                _sendAndUpdate(gs.startStop);
                _send(gs.key ? Cmd.startClock : Cmd.stopClock);
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3050),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                _sendAndUpdate(() => gs.resetShotClock(14));
                _send(Cmd.shotClock14);
              },
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('SC 14'),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3050),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                _sendAndUpdate(() => gs.resetShotClock(24));
                _send(Cmd.shotClock24);
              },
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('SC 24'),
              ),
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
    onPlus1: () {
      gs.teamAScorePlus1();
      _send(Cmd.teamAPlus1);
    },
    onPlus2: () {
      gs.teamAScorePlus2();
      _send(Cmd.teamAPlus2);
    },
    onMinus1: () {
      gs.teamAScoreMinus1();
      _send(Cmd.teamAMinus1);
    },
    onFoulPlus: () {
      gs.teamAFoulPlus();
      _send(Cmd.teamAFoulPlus);
    },
    onFoulMinus: () {
      gs.teamAFoulMinus();
      _send(Cmd.teamAFoulMinus);
    },
    onTolMinus: () {
      gs.teamATOLMinus();
      _send(Cmd.teamATolMinus);
    },
    onTolPlus: () {
      gs.teamATOLPlus();
      _send(Cmd.teamATolPlus);
    },
  );

  Widget _teamB(GameState gs) => TeamPanel(
    teamName: 'TEAM B',
    score: gs.teamBScore,
    fouls: gs.teamBFouls,
    tol: gs.teamBTOL,
    accentColor: Colors.red,
    onPlus1: () {
      gs.teamBScorePlus1();
      _send(Cmd.teamBPlus1);
    },
    onPlus2: () {
      gs.teamBScorePlus2();
      _send(Cmd.teamBPlus2);
    },
    onMinus1: () {
      gs.teamBScoreMinus1();
      _send(Cmd.teamBMinus1);
    },
    onFoulPlus: () {
      gs.teamBFoulPlus();
      _send(Cmd.teamBFoulPlus);
    },
    onFoulMinus: () {
      gs.teamBFoulMinus();
      _send(Cmd.teamBFoulMinus);
    },
    onTolMinus: () {
      gs.teamBTOLMinus();
      _send(Cmd.teamBTolMinus);
    },
    onTolPlus: () {
      gs.teamBTOLPlus();
      _send(Cmd.teamBTolPlus);
    },
  );

  // ── Portrait layout ───────────────────────────────────────────────────────
  // Stack: ConnectionBar → TimerDisplay → Controls → [TeamA | TeamB] → Bottom
  Widget _portraitLayout(GameState gs, BleService ble) {
    return Column(
      children: [
        const ConnectionBar(),
        const TimerDisplay(),
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
                  children: [const TimerDisplay(), _controlRow(gs)],
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

class _BottomBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _BottomBtn({
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1E3050),
  });

  @override
  Widget build(BuildContext context) {
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
