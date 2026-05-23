# Gemini Context: Scoreboard Controller

## Purpose

This repository contains a Flutter Android app for controlling a physical basketball scoreboard over Bluetooth Low Energy (BLE).

The intended architecture is:

- The Flutter app is the single source of truth.
- The Arduino-based scoreboard is a display follower.
- The scoreboard should mirror the app state, especially the game timer and shot clock.
- The Arduino should not run an independent authoritative timer unless it is explicitly designed as a temporary fail-safe.

The highest-priority product requirement is timer synchronization. The app timer must drive the physical scoreboard timer.

## Repository Overview

This is a Flutter project named `scoreboard_app`.

Important files:

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry point. Sets device orientations, creates app-wide providers, and starts at `SplashScreen`. |
| `lib/models/game_state.dart` | Central app state for period, game timer, shot clock, scores, fouls, timeouts, horn, and running flags. |
| `lib/models/commands.dart` | ASCII command byte constants sent to the Arduino scoreboard. |
| `lib/services/ble_service.dart` | BLE scanning, connection management, and packet/command transmission. |
| `lib/services/timer_service.dart` | Runs the periodic 200 ms timer loop and sends timer state packets over BLE. |
| `lib/screens/splash_screen.dart` | Requests Bluetooth/location permissions before scanning. |
| `lib/screens/scan_screen.dart` | Scans for BLE devices, connects up to four scoreboards, and opens the scoreboard UI. |
| `lib/screens/scoreboard_screen.dart` | Main controller screen for timer, horn, shot clock, teams, period, and game reset. |
| `lib/widgets/timer_display.dart` | Displays game time, period, and shot clock. |
| `lib/widgets/team_panel.dart` | Reusable team score/foul/timeout controls. |
| `lib/widgets/connection_bar.dart` | Shows connected scoreboard count and links back to scanning. |
| `chat.md` | Prior analysis and working notes about BLE timer synchronization. |

## Runtime Flow

1. `main.dart` creates two global providers:
   - `GameState`
   - `BleService`

2. `SplashScreen` requests permissions:
   - Android BLE scan/connect permissions.
   - Location permission for BLE scanning compatibility.

3. If permissions are granted, the app navigates to `ScanScreen`.

4. `ScanScreen` starts BLE scanning and lists nearby devices.

5. The user connects to one or more scoreboard devices.
   - The current max is four connected scoreboards.

6. The user opens `ScoreboardScreen`.

7. `ScoreboardScreen` creates and starts `TimerService`.

8. `TimerService` ticks every 200 ms.

9. On each tick:
   - `GameState.tickGameTimer()` advances the game timer if running.
   - `GameState.tickShotClock()` advances the shot clock if running.
   - The UI is notified.
   - A timer packet is sent to every connected scoreboard.

10. Button taps mutate `GameState` and/or send ASCII command bytes through `BleService`.

## Current State Model

`GameState` is the central state holder and currently acts as the app source of truth.

### Game Metadata

- `period`: current quarter/period. Defaults to `1`.

### Game Timer

The game timer stores each digit separately. This appears to match an older MIT App Inventor implementation.

Default game time is `10:00.0`.

Fields:

- `min1`
- `min2`
- `sec1`
- `sec2`
- `mSec`

Displayed format:

```text
min1 min2 : sec1 sec2 . mSec
```

Example:

```text
10:00.0
```

The timer ticks every 200 ms. `mSec` decrements by `2`, so the displayed tenths move as:

```text
8, 6, 4, 2, 0
```

### Shot Clock

Default shot clock is `24.0`.

Fields:

- `shot1`
- `shot2`
- `mShot`

Displayed format:

```text
shot1 shot2 . mShot
```

Example:

```text
24.0
```

### Control Flags

- `key`: whether the game timer is running.
- `shotclockStatus`: whether the shot clock is running.
- `hornx`: `0` means horn off, `1` means horn triggered.

### Team State

Team A:

- `teamAScore`
- `teamAFouls`
- `teamATOL`

Team B:

- `teamBScore`
- `teamBFouls`
- `teamBTOL`

`TOL` means timeouts left.

## BLE Implementation

BLE code lives in `lib/services/ble_service.dart`.

### BLE UUIDs

Current service UUID:

```text
0000ffe0-0000-1000-8000-00805f9b34fb
```

Current characteristic UUID:

```text
0000ffe1-0000-1000-8000-00805f9b34fb
```

These UUIDs are commonly used by simple BLE serial modules and Arduino BLE bridge setups.

### Connection Model

`BleService` supports up to four connected scoreboard devices.

It tracks:

- scan results
- connected devices
- connection status
- discovered write characteristic

When sending data, it writes to every connected device using:

```dart
characteristic.write(data, withoutResponse: true)
```

This means the app does not currently wait for BLE write acknowledgement.

## BLE Packet Protocol

There are two current transmission styles:

1. Full timer update packets.
2. Single ASCII command bytes.

### Timer Update Packet

`GameState.buildPacket()` returns:

```dart
'*$min1$min2$sec1$sec2$mSec$shot1$shot2$mShot$hornx$min1'
```

Packet shape:

```text
* Min1 Min2 Sec1 Sec2 mSec Shot1 Shot2 mShot Hornx Min1
```

Example for `10:00.0`, shot clock `24.0`, horn off:

```text
*1000024001
```

Notes:

- `*` marks the message as a timer update packet.
- The final `Min1` duplicate appears to come from the old MIT App Inventor packet format.
- Preserve this format unless the Arduino firmware is updated at the same time.

### Command Bytes

`lib/models/commands.dart` defines single-byte ASCII commands.

| Command | ASCII | Meaning |
|---|---:|---|
| `Cmd.null_` | `-` | Null / no-op |
| `Cmd.horn` | `_` | Horn |
| `Cmd.newGame` | `v` | New game |
| `Cmd.startClock` | `s` | Start game clock |
| `Cmd.stopClock` | `t` | Stop game clock |
| `Cmd.resetClock` | `u` | Reset game clock |
| `Cmd.startShotClock` | `x` | Start shot clock |
| `Cmd.stopShotClock` | `y` | Stop shot clock |
| `Cmd.resetShotClock` | `z` | Reset shot clock |
| `Cmd.shotClock14` | `q` | Set shot clock to 14 |
| `Cmd.shotClock24` | `r` | Set shot clock to 24 |
| `Cmd.teamAPlus1` | `j` | Team A score +1 |
| `Cmd.teamAPlus2` | `k` | Team A score +2 |
| `Cmd.teamAMinus1` | `m` | Team A score -1 |
| `Cmd.teamAFoulPlus` | `l` | Team A foul +1 |
| `Cmd.teamAFoulMinus` | `C` | Team A foul -1 |
| `Cmd.teamATolMinus` | `n` | Team A timeout left -1 |
| `Cmd.teamATolPlus` | `D` | Team A timeout left +1 |
| `Cmd.teamBPlus1` | `a` | Team B score +1 |
| `Cmd.teamBPlus2` | `b` | Team B score +2 |
| `Cmd.teamBMinus1` | `d` | Team B score -1 |
| `Cmd.teamBFoulPlus` | `c` | Team B foul +1 |
| `Cmd.teamBFoulMinus` | `A` | Team B foul -1 |
| `Cmd.teamBTolMinus` | `e` | Team B timeout left -1 |
| `Cmd.teamBTolPlus` | `B` | Team B timeout left +1 |
| `Cmd.rightArrow` | `W` | Right arrow |
| `Cmd.leftArrow` | `V` | Left arrow |

## Important Current Behavior

### Timer Behavior

`TimerService` starts when `ScoreboardScreen` opens and stops when the screen is disposed.

The timer service always has an active periodic timer, but it only changes timer values when:

- `GameState.key` is true for the game timer.
- `GameState.shotclockStatus` is true for the shot clock.

When neither timer is running, ticks do not send timer packets.

### Start / Stop

The main START/STOP button:

1. Toggles `GameState.key`.
2. Starts or stops the shot clock with the game clock.
3. Sends a full timer packet.
4. Sends either `Cmd.startClock` or `Cmd.stopClock`.

### Shot Clock Reset

The `SC 14` and `SC 24` buttons:

1. Update app shot clock state.
2. Send a full timer packet.
3. Send either `Cmd.shotClock14` or `Cmd.shotClock24`.

### Scores, Fouls, and Timeouts

Team score, foul, and timeout buttons currently:

1. Update local `GameState`.
2. Send only a single command byte.

They do not currently send a full authoritative state packet after every score/foul/timeout update.

This matters for synchronization reliability.

## Single Source of Truth Requirement

The target design should treat the Flutter app as authoritative.

The Arduino scoreboard should:

- Receive app state.
- Render app state.
- Avoid making independent long-term decisions about time, score, fouls, period, or timeouts.

If BLE drops, the Arduino should have a clear fallback policy. Recommended policy:

- Freeze the displayed state after a short timeout.
- Show a disconnected indicator if hardware supports it.
- Resume mirroring when the app reconnects and sends a fresh full state packet.

Avoid designing the Arduino as a competing timer authority unless the product explicitly requires autonomous offline operation.

## Known Design Risks

### 1. Timer Drift

The app sends timer packets every 200 ms while timers are running.

Risk:

- BLE writes may be delayed or dropped.
- The Arduino may display stale time if it runs its own countdown between packets.

Recommended direction:

- Arduino should render the latest received app time.
- If Arduino interpolates between packets, it must resync to each app packet.
- The app should periodically send absolute state, not only deltas.

### 2. Command-Only Score Updates

Scores, fouls, and timeouts currently rely on command bytes.

Risk:

- If a BLE command byte is dropped, the scoreboard and app diverge.

Recommended direction:

- Prefer full authoritative state packets for all displayed scoreboard state.
- Keep command bytes only if the Arduino firmware requires backward compatibility.
- If command bytes remain, add periodic full-state reconciliation.

### 3. No Write Acknowledgement

BLE writes use `withoutResponse: true`.

Risk:

- The app cannot know whether the scoreboard received a packet.

Recommended direction:

- Consider write-with-response for critical actions.
- Or add Arduino acknowledgements through a notify characteristic if supported.
- At minimum, send periodic full-state packets while connected.

### 4. Reconnect State

On reconnect, the scoreboard must receive the current full app state.

Risk:

- A reconnected board may show default or stale values.

Recommended direction:

- Send a full state snapshot immediately after connection.
- Send another snapshot when entering `ScoreboardScreen`.

### 5. Packet Format Limits

The current timer packet includes only timer and horn fields.

Risk:

- It cannot fully restore scoreboard state after packet loss or reconnect.

Recommended direction:

- Define a new full-state packet format if Arduino firmware can change.
- Keep the old `*...` timer packet only for backward compatibility.

## Suggested Future Full-State Packet

Only use this if the Arduino firmware can be updated.

A clearer protocol could use prefixed, delimited packets:

```text
S|period=1|game=10:00.0|shot=24.0|run=0|shotRun=0|horn=0|aScore=0|bScore=0|aFouls=0|bFouls=0|aTol=5|bTol=5
```

Benefits:

- Human-readable during debugging.
- Can include all displayed state.
- Easier to extend without relying on fixed digit positions.

Tradeoff:

- Requires matching Arduino parser changes.
- Larger packets may need BLE MTU consideration.

If the Arduino code must stay fixed, preserve the existing command bytes and `*` packet format.

## App Screens and User Experience

### Splash Screen

Purpose:

- Request Bluetooth and location permissions.
- Block the user until required permissions are granted.
- Offer app settings if permissions are permanently denied.

### Scan Screen

Purpose:

- Scan for BLE scoreboards.
- Show available devices.
- Connect or disconnect scoreboards.
- Show four connection slots.
- Navigate to the scoreboard controller once at least one board is connected.

### Scoreboard Screen

Purpose:

- Main live game controller.
- Keeps the device awake using `wakelock_plus`.
- Shows connection status.
- Shows game timer, period, and shot clock.
- Provides START/STOP, HORN, SC 14, SC 24 controls.
- Provides Team A and Team B controls.
- Provides left/right arrow commands.
- Provides Next QTR and New Game actions.

The screen supports portrait and landscape layouts.

## Development Environment

This is a Flutter project with Android support.

Expected setup:

```powershell
flutter doctor
flutter pub get
flutter devices
flutter run
```

This app should be tested on a physical Android device for BLE behavior. An emulator may launch the UI but is not enough for reliable Bluetooth hardware testing.

## Guidance for Gemini

When proposing changes, preserve these constraints:

- The Flutter app must remain the source of truth.
- The scoreboard should mirror app state.
- Timer sync is more important than local Arduino autonomy.
- BLE packet compatibility matters if the Arduino firmware is already deployed.
- Do not introduce a second authoritative timer without explicitly explaining the tradeoff.

When analyzing the code, focus on:

- Timer correctness.
- BLE reliability.
- Reconnect behavior.
- Packet loss recovery.
- Whether all visible scoreboard state can be resent authoritatively.
- Separation between UI, app state, BLE protocol, and timer engine.

Good improvement directions:

- Add a full-state packet.
- Send state snapshots on connect, reconnect, screen open, and every important mutation.
- Add a protocol version.
- Add sequence numbers.
- Add acknowledgements if Arduino supports notify/indicate.
- Add debug logging for sent packets and connection state.
- Add tests for timer countdown edge cases.
- Add tests for packet formatting.

Avoid:

- Making the Arduino the primary timer source.
- Updating app UI based on unverified Arduino state unless the architecture changes to bidirectional sync.
- Optimizing UI before fixing synchronization semantics.
- Adding complicated automation before the BLE protocol is reliable.

## Current Open Questions

These questions should be answered before major protocol changes:

1. Can the Arduino firmware be changed, or must the app preserve the current packet protocol?
2. Does the scoreboard display scores, fouls, timeouts, period, horn, arrows, timer, and shot clock?
3. Should the Arduino freeze or continue counting if BLE disconnects during a running game?
4. Should the app support multiple scoreboards showing the same state at the same time?
5. Does the Arduino support BLE notifications back to the app for acknowledgements?
6. What BLE module or board is used by the scoreboard?
7. Is 200 ms transmission frequent enough for the physical display?
8. Should the app send full state even while the timer is paused?

