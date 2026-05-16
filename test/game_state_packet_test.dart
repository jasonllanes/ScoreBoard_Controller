import 'package:flutter_test/flutter_test.dart';
import 'package:scoreboard_app/models/game_state.dart';

void main() {
  test('buildPacket uses _ prefix, no line ending (MIT blocks evidence)', () {
    expect(GameState().buildPacket(), '_1000024001');
    expect(GameState.timerPacketPrefix, '_');
    expect(GameState.timerPacketLineEnding, '');
    expect(GameState.timerCommandFirst, true);
  });

  test('newGame() resets buildPacket() to default timer state', () {
    final gs = GameState();
    gs.min1 = 0;
    gs.sec1 = 3;
    gs.teamAScore = 10;
    gs.newGame();
    expect(gs.buildPacket(), '_1000024001');
  });
}
