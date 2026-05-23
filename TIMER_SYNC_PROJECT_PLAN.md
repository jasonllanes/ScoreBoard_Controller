# Project: Scoreboard Timer Sync Stabilization

**Goal**: Make the Flutter app timer align with the physical Arduino scoreboard timer while preserving the locked legacy BLE protocol.
**Timeline**: 2-4 focused test/fix cycles, depending on hardware behavior.
**Team**: Claude = implementer, Codex = tester/reviewer, User = hardware operator/client feedback loop.
**Constraints**:

- Arduino firmware is treated as locked for this phase.
- BLE protocol must stay backward compatible.
- Physical Android device and physical scoreboard are required for validation.
- Timer sync is higher priority than UI polish or architecture cleanup.
- Do not introduce a new packet protocol until hardware constraints are confirmed.

---

## Milestones

| # | Milestone | Target | Owner | Success Criteria |
|---|---|---|---|---|
| 1 | Baseline Hardware Behavior Captured | Cycle 1 | Codex + User | We know whether `_` or `*` wakes/updates the board, and whether `s`/`t` are required. |
| 2 | Legacy Timer Protocol Confirmed | Cycle 1-2 | Claude | App sends exactly the prefix and command sequence the board accepts. |
| 3 | Timer Alignment Verified | Cycle 2-3 | Codex + User | App and physical scoreboard remain visually aligned for at least 2 minutes after START/STOP cycles. |
| 4 | Reconnect/Restart Behavior Verified | Cycle 3-4 | Codex + User | After hot restart/app restart/reconnect, board receives current timer state and can start cleanly. |
| 5 | Phase 1 Stabilization Complete | Cycle 4 | All | Known timer issue is either fixed or reduced to a documented firmware/BLE limitation. |

---

## Phase 1: Confirm Legacy Protocol (Critical Path)

| Task | Effort | Owner | Depends On | Done Criteria |
|---|---:|---|---|---|
| Document current outgoing timer packet | 1h | Claude | Current code | A short note shows exact START, STOP, and tick bytes sent by Flutter. |
| Add temporary BLE send logging | 2h | Claude | Current code | Debug logs show every command byte and timer packet sent from app. |
| Test current `_` prefix on hardware | 1h | Codex + User | Logging build | We know if board wakes and timer updates with `_1000024001` style packets. |
| Test fallback `*` prefix on hardware if `_` fails | 1h | Claude + Codex | `_` test result | We know if board expects `*1000024001` instead. |
| Confirm `s` / `t` requirement | 1h | Codex + User | Logging build | Board behavior is observed with START/STOP command bytes present. |

**Phase 1 rule**: Change only one protocol variable per test: prefix, command byte, or cadence. No bundled fixes.

---

## Phase 2: Timer Alignment Fixes

| Task | Effort | Owner | Depends On | Done Criteria |
|---|---:|---|---|---|
| Lock confirmed timer prefix in `GameState.buildPacket()` | 1h | Claude | Phase 1 | Unit test covers the confirmed packet prefix and default packet string. |
| Ensure START sends state then `s` in legacy-compatible order | 1-2h | Claude | Phase 1 | Physical board starts reliably from 10:00.0 and receives the latest timer snapshot. |
| Ensure STOP sends final state and `t` | 1-2h | Claude | Phase 1 | Physical board stops on the same visible time as the app. |
| Verify 200 ms tick cadence on app side | 2h | Codex | Logging | Logs show timer packets emitted at expected cadence while running. |
| Run 2-minute drift test | 1h | Codex + User | Confirmed prefix/order | Board and app stay visually aligned after 2 minutes. |
| Run START/STOP repeat test | 1h | Codex + User | Confirmed prefix/order | 10 repeated START/STOP cycles do not leave board frozen or offset. |

---

## Phase 3: Reconnect and Recovery

| Task | Effort | Owner | Depends On | Done Criteria |
|---|---:|---|---|---|
| Send timer snapshot after BLE connect | 2-4h | Claude | Phase 2 | After reconnect, board gets the app's current timer packet before user presses controls. |
| Send timer snapshot when entering `ScoreboardScreen` | 1-2h | Claude | Phase 2 | Opening the controller screen refreshes the physical board timer. |
| Test hot restart and reconnect flow | 1h | Codex + User | Snapshot changes | After `R`, reconnect works and board starts from app state. |
| Test physical board power-cycle recovery | 1h | Codex + User | Snapshot changes | After board reset, reconnect/rescan restores timer display. |

---

## Phase 4: Reliability Hardening

| Task | Effort | Owner | Depends On | Done Criteria |
|---|---:|---|---|---|
| Add packet/command debug mode flag | 2h | Claude | Phase 2 | Logs can be enabled for hardware sessions without noisy production output. |
| Evaluate write-with-response for START/STOP only | 2-4h | Claude + Codex | Phase 2 | We know whether critical command writes can use acknowledgements without delaying timer ticks. |
| Document BLE packet loss risks | 1h | Codex | Phase 2 | Notes explain why score/foul commands can desync and why this is deferred. |
| Create manual QA checklist | 1h | Codex | Phase 2 | A repeatable hardware checklist exists for timer, shot clock, START/STOP, reconnect. |

---

## Dependencies Map

```text
Confirm locked firmware assumptions
  -> Add BLE send logging
    -> Test prefix `_`
      -> Test prefix `*` if needed
        -> Lock confirmed prefix
          -> Verify START/STOP order
            -> 2-minute drift test
              -> Reconnect snapshot behavior
                -> Reliability hardening
```

Critical path:

```text
Protocol confirmation -> Prefix/order fix -> Physical drift test -> Reconnect behavior
```

---

## Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|---|---|---:|---|
| Wrong packet prefix assumption | High | High | Test `_` and `*` separately on hardware with logs. |
| Arduino requires command bytes and ignores packets while paused | High | Medium | Keep `s`/`t`; do not remove legacy commands again. |
| BLE write drops packets silently | High | Medium | Add logging; consider write-with-response only for critical commands. |
| Timer packets block score commands or vice versa | Medium | Medium | Keep timer packet compact and score commands single-byte for Phase 1. |
| Hot reload keeps stale BLE/hardware state | Medium | Medium | Use hot restart for protocol changes; reconnect BLE; power-cycle board when frozen. |
| Client protocol details are incomplete | High | Medium | Treat physical board behavior as source of truth and document each test result. |

---

## Resource Allocation

| Role | Hours/Week | Key Responsibilities |
|---|---:|---|
| Claude | 4-8h | Implement focused protocol/logging fixes, keep changes small, update tests. |
| Codex | 4-8h | Review diffs, run Flutter tests, create hardware test checklist, interpret results. |
| User | 2-4h | Operate phone/scoreboard, observe physical behavior, provide client constraints. |

---

## Immediate Next Tasks

1. Claude adds temporary BLE send logging for command bytes and timer packets.
2. Codex verifies tests still pass.
3. User runs on physical device with hot restart and reconnect.
4. Test `_` prefix with `s`/`t` restored.
5. If frozen or rejected, Claude switches prefix back to `*`.
6. Codex verifies the 2-minute timer alignment test.

---

## Done Criteria for First Goal

The timer alignment goal is done when:

- Board starts when START is pressed.
- Board stops when STOP is pressed.
- App and physical board show the same game timer value after START.
- App and physical board remain visually aligned for at least 2 minutes.
- Reconnect or app hot restart does not leave the board stuck in a stale timer state.
- The confirmed legacy prefix and command sequence are documented in code/tests.
