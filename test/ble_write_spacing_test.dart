import 'package:flutter_test/flutter_test.dart';
import 'package:scoreboard_app/services/ble_service.dart';

// Guards the fix for the board showing 01:00 after NEW GAME: a command byte and
// the packet that follows must not land in the same BLE write chunk.
void main() {
  test('back-to-back writes are serialised and spaced', () async {
    final ble = BleService();
    final started = DateTime.now();

    final first = ble.sendCommand(0x76); // 'v'
    final second = ble.sendPacket('_1000024001');

    await first;
    final afterFirst = DateTime.now().difference(started);
    await second;
    final afterSecond = DateTime.now().difference(started);

    expect(afterSecond - afterFirst, greaterThanOrEqualTo(BleService.writeGap));
  });
}
