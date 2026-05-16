import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';

/// Large segment-style display for the game timer and shot clock.
class TimerDisplay extends StatelessWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    final gameTime = '${gs.min1}${gs.min2}:${gs.sec1}${gs.sec2}.${gs.mSec}';
    final shotClock = '${gs.shot1}${gs.shot2}.${gs.mShot}';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale font sizes relative to the available width so they always fit.
        final w = constraints.maxWidth;
        final timerFs = (w * 0.10).clamp(24.0, 60.0);
        final qtrFs = (w * 0.055).clamp(16.0, 40.0);
        final labelFs = (w * 0.018).clamp(8.0, 14.0);

        return Container(
          color: const Color(0xFF0A0E1A),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── Game timer ─────────────────────────────────────────────
              Flexible(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GAME TIME',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: labelFs,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        gameTime,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: timerFs,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Period badge ────────────────────────────────────────────
              Flexible(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QTR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: labelFs,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${gs.period}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: qtrFs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Shot clock ──────────────────────────────────────────────
              Flexible(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SHOT CLOCK',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: labelFs,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        shotClock,
                        style: TextStyle(
                          color: gs.shotclockStatus
                              ? Colors.redAccent
                              : Colors.white,
                          fontSize: timerFs,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
