import 'package:flutter/material.dart';

/// Reusable control panel for one team.
/// The parent passes in the current values and callbacks so this widget
/// stays stateless and purely presentational.
class TeamPanel extends StatelessWidget {
  final String teamName;
  final int score;
  final int fouls;
  final int tol; // timeouts left
  final Color accentColor;

  final VoidCallback onPlus1;
  final VoidCallback onPlus2;
  final VoidCallback onMinus1;
  final VoidCallback onFoulPlus;
  final VoidCallback onFoulMinus;
  final VoidCallback onTolMinus;
  final VoidCallback onTolPlus;

  const TeamPanel({
    super.key,
    required this.teamName,
    required this.score,
    required this.fouls,
    required this.tol,
    required this.accentColor,
    required this.onPlus1,
    required this.onPlus2,
    required this.onMinus1,
    required this.onFoulPlus,
    required this.onFoulMinus,
    required this.onTolMinus,
    required this.onTolPlus,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        // Scale sizes to available space; clamp so they stay usable.
        final scoreFs = (h * 0.28).clamp(28.0, 80.0);
        final nameFs = (h * 0.07).clamp(12.0, 22.0);
        final btnH = (h * 0.13).clamp(32.0, 52.0);
        final btnW = (w * 0.28).clamp(36.0, 70.0);
        final statFs = (h * 0.06).clamp(10.0, 18.0);
        final labelFs = (h * 0.05).clamp(9.0, 14.0);

        return Card(
          color: const Color(0xFF112233),
          margin: const EdgeInsets.all(4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: accentColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // ── Team name ────────────────────────────────────────────
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    teamName,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: nameFs,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // ── Score display ────────────────────────────────────────
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: scoreFs,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                // ── Score buttons ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScoreBtn(
                      label: '+1',
                      color: Colors.green,
                      onTap: onPlus1,
                      height: btnH,
                      width: btnW,
                    ),
                    const SizedBox(width: 4),
                    _ScoreBtn(
                      label: '+2',
                      color: Colors.lightGreen,
                      onTap: onPlus2,
                      height: btnH,
                      width: btnW,
                    ),
                    const SizedBox(width: 4),
                    _ScoreBtn(
                      label: '-1',
                      color: Colors.red,
                      onTap: onMinus1,
                      height: btnH,
                      width: btnW,
                    ),
                  ],
                ),

                const Divider(color: Colors.white12, height: 8),

                // ── Fouls ────────────────────────────────────────────────
                _StatRow(
                  label: 'FOULS',
                  value: '$fouls',
                  onMinus: onFoulMinus,
                  onPlus: onFoulPlus,
                  statFs: statFs,
                  labelFs: labelFs,
                  iconSize: (h * 0.045).clamp(10.0, 18.0),
                ),

                // ── Timeouts ─────────────────────────────────────────────
                _StatRow(
                  label: 'TOL',
                  value: '$tol',
                  onMinus: onTolMinus,
                  onPlus: onTolPlus,
                  statFs: statFs,
                  labelFs: labelFs,
                  iconSize: (h * 0.045).clamp(10.0, 18.0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double height;
  final double width;
  const _ScoreBtn({
    required this.label,
    required this.color,
    required this.onTap,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final double statFs;
  final double labelFs;
  final double iconSize;
  const _StatRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.statFs,
    required this.labelFs,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: labelFs,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Row(
          children: [
            _SmallBtn(icon: Icons.remove, onTap: onMinus, iconSize: iconSize),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: statFs,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            _SmallBtn(icon: Icons.add, onTap: onPlus, iconSize: iconSize),
          ],
        ),
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  const _SmallBtn({
    required this.icon,
    required this.onTap,
    required this.iconSize,
  });
  @override
  Widget build(BuildContext context) {
    final pad = (iconSize * 0.35).clamp(3.0, 8.0);
    return Material(
      color: const Color(0xFF1E3050),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Icon(icon, color: Colors.white70, size: iconSize),
        ),
      ),
    );
  }
}
