# Oops — Colmi R09 iOS App — Design (Iteration 0)

**Date:** 2026-06-11
**Status:** Approved design, pre-implementation
**Scope:** Iteration 0 only. This is the first vertical slice of a long, deliberately
incremental project.

## Vision (context, not this iteration)

A custom native iOS app for the **Colmi R09 smart ring** that looks and feels like a
stock Apple app, owns the full experience (connection, data collection, analysis), and
grows feature-by-feature over time toward Whoop-band depth. **As few features as
possible at each step.**

## Non-goals (explicitly out of scope, now and possibly forever)

- **Custom firmware.** The R09 uses a **Realtek RTL8762** SoC. The only Colmi custom
  firmware toolchain (`ATC_RF03_Ring`) targets the **BlueX RF03** chip (R02/R06) and
  **cannot run on the R09**. Reflashing is needed for *nothing* on the roadmap (it only
  buys higher-rate raw accel/PPG). Firmware is a separate, deferred track; if ever
  pursued, it would be on R02/R06 hardware, not the R09.
- For **iteration 0** specifically: no persistence, no charts, no historical sync, no
  metrics other than battery, no settings, no background mode, no AccessorySetupKit.

## Hardware & protocol facts (verified reference)

The R09 is protocol-compatible with the R02/R06/**R10** at the BLE command level. The
R10 shares the R09's Realtek chip and is on the canonical client's officially-compatible
list — strong evidence the R09 BLE path is solid. **No pairing, bonding, or auth** is
required; any BLE central can connect and read.

- **GATT service (Nordic-UART style):** `6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E`
  - **Write (RX):** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
  - **Notify (TX):** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- **Packet format:** fixed **16 bytes**. `byte[0]` = command; `bytes[1..14]` = payload
  (zero-padded); `byte[15]` = checksum = `sum(bytes[0..14]) % 255`.
- **Battery command:** `byte[0] = 0x03`. Response packet: `byte[1]` = level (%),
  `byte[2]` = charging (bool). Battery is a single request/response — no streaming —
  which is why it's iteration 0.

### Known R09 risk (design for it)
The R09's Realtek BLE stack is **flakier** than the RF03 rings: connections may need
retries, and it prefers being disconnected between command sessions. Design pattern:
**connect → do one job → disconnect**, with retry on failure. (iOS reinforces this:
`CBCharacteristic` references must be re-discovered on every reconnect.)

## Architecture — separate pure protocol from radio

The core design principle: the **protocol** (well-documented, deterministic) is isolated
from the **transport** (flaky, hardware-bound). This makes the gnarly part testable
without hardware and keeps the radio layer thin.

### `RingProtocol.swift` — pure Swift, zero CoreBluetooth
- Build a 16-byte packet from a command + payload, applying the checksum.
- `batteryCommand()` → the `0x03` request packet.
- `parseBattery(_ data: Data) -> BatteryStatus?` → `{ level: Int, charging: Bool }`.
- No async, no I/O. **Fully unit-testable on the Mac.**

### `RingBLEManager.swift` — CoreBluetooth, `@Observable`
- Wraps `CBCentralManager` + `CBPeripheral` delegates.
- Responsibilities: scan filtered by the service UUID, connect, (re)discover the write &
  notify characteristics, write a command, deliver notify bytes back.
- Publishes a small connection/result state for the UI. Owns the connect→read→disconnect
  flow and retry. Knows nothing about packet internals beyond calling `RingProtocol`.

### Views — SwiftUI, stock look
- A connection/state view and a battery view, built from system components and SF
  Symbols so the result reads as a native Apple app. Reflects: scanning, connecting,
  connected, battery value, charging, and a clear **"Bluetooth unavailable"** state
  (the Simulator and denied-permission case).

### Data flow (iteration 0)
`ContentView` → user taps connect → `RingBLEManager` scans by service UUID → connects →
discovers characteristics → subscribes to notify → writes `RingProtocol.batteryCommand()`
→ notify bytes arrive → `RingProtocol.parseBattery` → `BatteryStatus` published →
`BatteryView` renders → manager disconnects.

## Error handling
- Bluetooth powered off / unauthorized / unavailable → explicit UI state, no crash.
- Ring not found within a scan timeout → "ring not found, try again".
- Connect failure → bounded retry, then surface a retry button.
- Malformed/short notify packet → `parseBattery` returns `nil`; UI shows "couldn't read".

## Testing strategy
- **Protocol layer:** Swift Testing unit tests, run headless via `xcodebuild test` on the
  Mac. Covers packet building, checksum correctness, and battery parsing (incl. malformed
  input). No device or simulator needed.
- **Real battery read:** manual, on a **physical iPhone** (iOS 26) with the ring nearby,
  via free Apple ID development signing. **CoreBluetooth does not work in the Simulator.**
- **Simulator:** app runs and shows the graceful "Bluetooth unavailable" state.

## Tooling, target, layout
- **XcodeGen** (`brew install xcodegen`); `project.yml` is the source of truth, the
  `.xcodeproj` is regenerated (and git-ignored or committed per preference).
- **Min target: iOS 26.** Swift 6.2 / Xcode 26. App display name & target: **Oops**.
- Bundle id: `com.<tbd>.oops` (placeholder; the user sets the signing team in Xcode).

```
oops/
  project.yml                    # XcodeGen source of truth
  Oops/
    OopsApp.swift                # @main App
    Ring/
      RingProtocol.swift         # pure, tested
      RingBLEManager.swift       # CoreBluetooth, @Observable
    Views/
      ContentView.swift
      BatteryView.swift
    Info.plist                   # NSBluetoothAlwaysUsageDescription
  OopsTests/
    RingProtocolTests.swift
  CLAUDE.md
```

## Unknowns to verify against the real R09 (not blockers for building)
- Exact advertised name / whether the ring advertises the `6E40FFF0` service UUID for
  scan-filtering (fallback: scan all, match by name prefix).
- That the battery response byte layout (`level@1`, `charging@2`) holds on the R09
  specifically. Confirm on-device; adjust the parser if needed.

## Roadmap after iteration 0 (each its own slice; informational)
Live heart rate (real-time `0x69`/`0x6A`) → steps (logged) → SpO2 → persistence (local
store) → history & charts → sleep/stress → AccessorySetupKit pairing & background mode.
Each is an increment on the same protocol/transport/UI split established here.
