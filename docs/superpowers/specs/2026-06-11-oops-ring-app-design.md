# Oops — Colmi R09 iOS App — Design (Iteration 0)

**Date:** 2026-06-11
**Status:** Approved design, pre-implementation
**Scope:** Iteration 0 only. The first vertical slice of a long, deliberately
incremental project.

## Vision (context, not this iteration)

A custom native iOS app for the **Colmi R09 smart ring** that looks and feels like a
stock Apple app, owns the full experience (connection, data collection, analysis), and
grows feature-by-feature over time toward Whoop-band depth. **As few features as
possible at each step.**

## Key constraints driving this design

1. **The ring hasn't arrived yet.** The app must be fully buildable and runnable *now*,
   with **simulated** data — and must switch to the real ring with zero rewrite when it
   arrives. → solved by a transport abstraction (below).
2. **Local-only storage, no iCloud, by deliberate choice.** Data lives on the device.
   No CloudKit, no iCloud entitlements, no paid Apple Developer Program required for
   data.
3. **Stay on the free Apple Developer tier as long as possible.** No paid program ($99/yr)
   for now. This has two consequences we accept by choice: (a) HealthKit is **deferred**
   — its capability requires the paid program and breaks free-team device builds; (b)
   on-device builds expire after ~7 days. Iteration 0 sidesteps both because it runs in
   the **Simulator on the mock transport** (no device, no signing). When on-device
   testing is needed (once the ring arrives), **SideStore** automates the weekly re-sign
   over-the-air; the paid program ($99/yr → 1-year signing) remains the clean eventual
   fix, deferred until it's worth it (realistically, the heart-rate / HealthKit slice).

## Non-goals (explicitly out of scope)

- **Custom firmware.** The R09 uses a **Realtek RTL8762** SoC. The only Colmi custom
  firmware toolchain (`ATC_RF03_Ring`) targets the **BlueX RF03** chip (R02/R06) and
  **cannot run on the R09**. Reflashing is needed for *nothing* on the roadmap. Deferred
  indefinitely; if ever pursued, on R02/R06 hardware, not the R09.
- **iCloud / CloudKit sync — ever.** Local-only is a chosen constraint, not a deferral.
- **HealthKit — deferred indefinitely.** Its capability requires the paid Apple Developer
  Program and breaks free-team device builds. We design the metric pipeline to be
  HealthKit-*ready* (below) but do not add the capability or any HealthKit code until we
  choose to enroll. Battery has no HealthKit type regardless.
- **Iteration 0 specifically:** no charts, no historical sync, no metrics other than
  battery, no settings screen, no background BLE mode, no AccessorySetupKit pairing, no
  `MetricSink` fan-out (battery writes to SwiftData directly — the fan-out lands with the
  first health metric).

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
- **Battery command:** `byte[0] = 0x03`. Response: `byte[1]` = level (%),
  `byte[2]` = charging (bool). Single request/response, no streaming — why it's slice 0.

### Known R09 risk (design for it)
The R09's Realtek BLE stack is **flakier** than the RF03 rings: connections may need
retries, and it prefers being disconnected between command sessions. Pattern:
**connect → do one job → disconnect**, with retry. (iOS reinforces this: `CBCharacteristic`
references must be re-discovered on every reconnect.)

## Architecture

Four layers, each with one job, isolated by clear interfaces. The principle: keep the
**protocol** (deterministic, documented) and **persistence** separate from the
**transport** (flaky, hardware-bound), and make the transport swappable so we can
develop against a fake ring today.

### 1. `RingProtocol.swift` — pure Swift, zero CoreBluetooth
- Build a 16-byte packet from command + payload, applying the checksum.
- `batteryCommand()` → the `0x03` request packet.
- `parseBattery(_ data: Data) -> BatteryStatus?` → `{ level: Int, charging: Bool }`.
- No async, no I/O. **Fully unit-testable on the Mac.** Also used by the mock transport
  to *encode* responses, so simulated data is byte-accurate.

### 2. `RingTransport` — the swappable seam (protocol/interface)
A small interface: connect, disconnect, `send(Data)`, a stream of received `Data`, and a
connection-state signal. Two implementations:
- **`BLERingTransport`** — real CoreBluetooth: `CBCentralManager`/`CBPeripheral`, scans
  by the service UUID, discovers write/notify characteristics, owns the
  connect→read→disconnect flow + retry. Used on the iPhone once the ring arrives.
- **`MockRingTransport`** — a simulated ring. Receives the app's command packets and
  replies with realistic response packets built via `RingProtocol` (e.g. battery `0x03`
  → "72%, not charging"). Deterministic; runs anywhere including the Simulator and unit
  tests. Grows with us (later: fake HR stream, steps, etc.).

**Transport selection (composition root):** the Simulator and "no ring yet" use
`MockRingTransport`; a real device uses `BLERingTransport`. Chosen in one place so it's a
trivial switch. Default rule for now: `#if targetEnvironment(simulator)` → Mock, else BLE
— plus an easy manual override point for testing the mock on-device.

### 3. `RingManager.swift` — `@Observable`, transport-agnostic orchestrator
Holds a `RingTransport` (injected) + uses `RingProtocol` + writes to SwiftData. Drives
the flow (connect → send battery command → parse → persist → publish), exposes UI state
(connection status, current battery, last-updated time, error). Knows nothing about which
transport it's wired to.

### 4. Persistence — SwiftData, **local-only**
- `@Model BatteryReading { id; timestamp; level: Int; isCharging: Bool }`.
- `ModelContainer` with **no** `cloudKitDatabase` — local store only.
- Each successful battery read is saved; the UI shows the latest plus its timestamp.
  (Establishing the SwiftData stack now de-risks persistence before richer metrics
  arrive — even though battery history itself is minor.)

### Views — SwiftUI, stock look
A connection/state view + a battery view, built from system components and SF Symbols so
it reads as a native Apple app. States: scanning, connecting, connected, battery value +
charging + "as of <time>", and an explicit **"Bluetooth unavailable"** state.

### Data flow (iteration 0)
User taps connect → `RingManager` → transport connects → `RingManager` sends
`RingProtocol.batteryCommand()` → transport returns response bytes →
`RingProtocol.parseBattery` → `RingManager` saves a `BatteryReading` + publishes state →
`BatteryView` renders → transport disconnects. With `MockRingTransport` this whole path
runs today, no hardware.

## Error handling
- Bluetooth off / unauthorized / unavailable → explicit UI state, no crash.
- Ring not found within scan timeout → "ring not found, try again".
- Connect failure → bounded retry, then a retry button.
- Malformed/short notify packet → `parseBattery` returns `nil`; UI shows "couldn't read".

## Testing strategy
- **Protocol layer:** Swift Testing unit tests on the Mac — packet building, checksum,
  battery parse (incl. malformed input). No device/simulator.
- **Orchestration:** test `RingManager` against `MockRingTransport` — the full
  connect→read→persist→publish flow, deterministic, headless. SwiftData via an in-memory
  `ModelContainer` (`isStoredInMemoryOnly: true`).
- **Real battery read:** manual, on a **physical iPhone** (iOS 26) with the ring nearby,
  via free Apple ID signing, *once the ring arrives*. CoreBluetooth does not work in the
  Simulator.
- **Simulator today:** app runs end-to-end on the mock transport.

## Tooling, target, layout
- **XcodeGen** (`brew install xcodegen`); `project.yml` is the source of truth; the
  `.xcodeproj` is generated and git-ignored.
- **Min target: iOS 26.** Swift 6.2 / Xcode 26. App display name & target: **Oops**.
- Bundle id: `com.<tbd>.oops` (placeholder; the user sets the signing team in Xcode).

```
oops/
  project.yml                    # XcodeGen source of truth
  .gitignore                     # ignores generated *.xcodeproj, build artifacts
  Oops/
    OopsApp.swift                # @main App; composition root (picks transport)
    Ring/
      RingProtocol.swift         # pure, tested
      RingTransport.swift        # protocol/interface
      BLERingTransport.swift     # CoreBluetooth implementation
      MockRingTransport.swift    # simulated ring
      RingManager.swift          # @Observable orchestrator
    Model/
      BatteryReading.swift       # @Model, local-only SwiftData
    Views/
      ContentView.swift
      BatteryView.swift
    Info.plist                   # NSBluetoothAlwaysUsageDescription
  OopsTests/
    RingProtocolTests.swift
    RingManagerTests.swift       # uses MockRingTransport + in-memory SwiftData
  CLAUDE.md
```

## Unknowns to verify against the real R09 (not blockers for building)
- Exact advertised name / whether the ring advertises the `6E40FFF0` service UUID for
  scan-filtering (fallback: scan all, match by name prefix).
- That the battery response byte layout (`level@1`, `charging@2`) holds on the R09.
  Confirm on-device; adjust the parser if needed. The mock encodes the *assumed* layout,
  so a mismatch is a one-line fix isolated to `RingProtocol`.

## HealthKit-readiness (deferred build, design-aware now)

HealthKit is not built in iteration 0 and not until we choose to enroll in the paid
program. But it's the eventual answer to "health metrics on my other Apple devices"
*without* CloudKit: HealthKit data syncs across **iPhone + Apple Watch** via the system's
end-to-end-encrypted iCloud Health, with zero CloudKit code (iPad has no Health app — the
one gap). To make that a clean plug-in later rather than a refactor, we keep these shapes
in mind now (and adopt them when the first health metric lands):

- **`MetricSink` fan-out:** decoded readings flow to a set of sinks. `SwiftDataMetricSink`
  is always on and is the local source of truth; `HealthKitMetricSink` is added later and
  only handles metrics that have a HealthKit type.
- **Normalized `MetricSample`** carrying value, unit, timestamp(s), and **ring provenance**
  (serial, firmware) — provenance maps later onto `HKDevice`, and (serial + kind +
  timestamp) hashes into `HKMetadataKeySyncIdentifier` for idempotent, duplicate-free
  re-sync of historical data.
- **`MetricKind` enum** where each case declares its HealthKit mapping or `nil` — e.g.
  `.heartRate → (.heartRate, count/min)`, `.spo2 → (.oxygenSaturation, percent 0–1)`,
  `.steps → (.stepCount, count)`, `.battery → nil`. The single source of truth for the
  type table; battery and any derived/proprietary scores map to `nil` (SwiftData-only).

**Free-tier path into Apple Health (no paid program): the Shortcuts bridge.** A sideloaded
app can't hold the HealthKit entitlement, but it can expose readings via **App Intents**
(no entitlement, free-tier OK); a user **Shortcut** then loops them into the **"Log Health
Sample"** action, run unattended by a Time-of-Day automation. Verified precedent:
OuraAppleHealth. Honest scope — good for **daily-summary / spot values** (resting HR,
nightly SpO2 / HRV / temperature, daily steps, a sleep block), **not** real-time HR or
bulk historical backfill, with these costs: data appears under source "Shortcuts" (not
Oops); no HealthKit sync-identifier, so **we dedupe via an app-side high-water-mark**;
Health permission must be re-granted after each ~7-day re-sign; and the `Log Health Sample`
type field can't be a variable, so the Shortcut needs one loop per metric. This becomes a
third **`MetricSink`** option — `ShortcutsHealthExport` via App Intents — alongside
`SwiftDataMetricSink` (always) and full `HealthKitMetricSink` (only if we ever enroll). No
other free route works (Apple Health has no arbitrary-sample import; LiveContainer doesn't
grant the entitlement; TrollStore doesn't support iOS 26). This is the strongest argument
for designing the sink fan-out early — it keeps all three Health paths open at zero cost.

Iteration 0 does **not** introduce any of these — `RingManager` writes `BatteryReading` to
SwiftData directly. They are captured here so the heart-rate slice slots them in cleanly.

## Roadmap after iteration 0 (each its own slice; informational)
Heart rate is the next slice and the natural moment to: introduce the `MetricSink`
fan-out, add the HealthKit sink + capability, and enroll in the paid program (which also
ends the 7-day re-deploy). Sequence: **live heart rate** (real-time `0x69`/`0x6A`, plus a
faked stream in `MockRingTransport`) → steps → SpO2 → history & charts (SwiftData) →
sleep/stress → AccessorySetupKit pairing & background mode. Every slice is an increment on
the protocol / transport / manager / persistence split established here.
