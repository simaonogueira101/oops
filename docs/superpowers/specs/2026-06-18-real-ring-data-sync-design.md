# Real ring data: live + 7-day historical sync

**Status:** Design — approved for spec review
**Date:** 2026-06-18
**Slice:** Foundation + wire real data (slices 1 & 2 of the larger "remove all mock data" effort), **including** app-layer ring binding.

## Goal

Replace `MockHealthData` with real data read from the physical Colmi R09 over BLE: a
live spot reading plus a 7-day historical sync that runs when the app opens. Every metric
the ring actually measures is shown from real data and persisted locally (SwiftData). Metrics
the ring can't yet provide keep their screens but render an honest placeholder until a later
slice fills them.

This builds directly on the verified BLE foundation (`BLERingTransport`, `RingProtocol`,
`RingManager`, `RingScanMatcher`) landed on 2026-06-18.

## What the R09 actually provides (verified)

| Metric | Opcode | Live | Historical | In this slice |
|---|---|---|---|---|
| Battery | `0x03` | ✓ | — | ✓ (already done) |
| Time sync (set ring clock, UTC/BCD) | `0x01` | set | — | ✓ |
| Heart rate — live spot | `0x69`/`0x6A` (type 1) | ✓ | — | ✓ |
| Heart rate — history (5-min, 288/day) | `0x15` | — | ✓ | ✓ |
| Steps / calories / distance (15-min, 96/day) | `0x43` | (offset 0) | ✓ | ✓ |
| Sleep + stages (ring-computed) | `0x44` | — | ✓ | ✓ |
| Stress | `0x37` | — | ✓ | ✓ |
| SpO2 (live + history) | `0x69` type 3 / `0x2C`+sync | ✓ | ✓ | ✓ |

### Deferred — kept on screen as a clear placeholder, NOT faked

- **Recovery score, Strain score, resting HR, sleep performance, HRV proxy** — computed from
  real signals in a later "derived metrics" slice (slice 3). Resting HR and sleep performance
  are straightforwardly derivable; recovery/strain/HRV are our own formulas.
- **Body temperature** — the R09 hardware has the sensor, but no public BLE opcode is known.
  A reverse-engineering effort is underway to find the vendor command; until then, placeholder.
- **Respiratory rate** — derivable from the raw PPG waveform (the same optical signal SpO2
  comes from). Future slice once we can pull the PPG; placeholder for now. **Not removed.**

The placeholder is a dash / "—" (or "Not available yet"), never a fabricated number.

## Architecture

### 1. Sync session (the core shift)

Today `RingManager` does connect → one command → disconnect. Historical sync needs many
commands per connection, several returning **multi-packet paged responses**. Changes:

- **Transport gains a paged read.** Alongside the existing one-shot `send(_:) -> Data`, add a
  way to send a command and collect inbound notify packets until a per-command predicate marks
  the last packet (each packet still bounded by the existing response timeout; a missing
  terminator fails that one fetch, not the session). Concretely, the transport exposes the
  inbound packet stream (e.g. an `AsyncStream<Data>` of notify packets, or a
  `send(_:collectWhile:)` accumulator). The mock transport implements the same surface.
- **`RingManager.refreshBattery()` becomes `sync()`** — one connection that runs, in order:
  1. set clock (`0x01`, UTC/BCD)
  2. battery (`0x03`)
  3. spot live HR (`0x69` type 1, stop with `0x6A`)
  4. for each **missing day** (since last sync per metric, capped at 7): HR (`0x15`),
     steps/cal/distance (`0x43`), sleep (`0x44`), stress (`0x37`), SpO2
  5. persist, then disconnect.
- **Partial-failure tolerant:** a failed metric or day is logged and skipped; everything that
  succeeded is still saved. The session never leaves the radio connected on error (existing
  `disconnect()` in all paths).
- Triggered exactly where `refreshBattery()` is today: on open, on foreground, every 30 min
  while open (re-entrancy guarded, as now).

### 2. Protocol layer (`RingProtocol` expansion)

Each metric gets, in pure transport-agnostic code:
- a **command builder** (handles per-command payload: timestamps as 4-byte LE Unix or BCD,
  day offsets, BCD clock), and
- a **paged-response parser** — a small accumulator that takes the ordered packets and returns
  typed samples, plus an `isLastPacket(_:)` predicate the session uses to stop collecting.

Documented layouts to encode:
- **Time `0x01`:** 7 BCD bytes `[year-2000, month, day, hour, minute, second, language=1]`, UTC.
- **HR history `0x15`:** request = 4-byte LE Unix midnight; response paged by `byte[1]` subtype
  (0=header w/ packet count + interval, 1=first data (4-byte start ts + 9 values), 2..N=13
  values, 255=error). 5-min cadence.
- **Steps `0x43`:** request = `[dayOffset, 0x0f,0x00,0x5f,0x01]`; response paged, 15-min slots,
  BCD date in `[1..3]`, time index `[4]`, calories LE `[7..8]` (×10 when header `byte[1]==240`),
  steps LE `[9..10]`, distance(m) LE `[11..12]`.
- **Sleep `0x44`, Stress `0x37`, SpO2 (`0x2C`+sync / live type 3):** parse per the
  Gadgetbridge-documented layouts; ring computes sleep stages itself (we don't re-stage).
- **Live HR `0x69`:** request `[0x69, type, 0x01]`; response `[0x69, type, err, value]`,
  `byte[3]` = BPM when `byte[2]==0`; stop with `0x6A`.

All parsers are unit-tested against **synthetic packet fixtures** built from these layouts —
same discipline as the existing `parseBattery` tests. Checksums validated.

### 3. Persistence (SwiftData, local-only — no iCloud)

Granular sample `@Model`s, deduped by timestamp; daily aggregates computed on read:
- `HeartRateSample(timestamp, bpm)` — 5-min.
- `ActivitySample(timestamp, steps, calories, distanceMeters)` — 15-min.
- `SpO2Sample(timestamp, percent)`.
- `StressSample(timestamp, value)`.
- Persisted `SleepSessionRecord` with stage intervals (mirrors the existing in-memory
  `SleepSession`/`SleepStageInterval` shapes so the chart layer is unchanged).
- `BatteryReading` stays as-is.
- `RingSyncMeta` — bound-ring identifier + name, and last-synced day per metric, so sync only
  fetches missing days (cap 7). Lives in the same local container.

The container-open `try / wipe-and-recreate` guard in `iOS/OopsApp` already covers schema
growth; adding these models exercises that path.

### 4. Ring binding ("remember my ring" — app-layer claim)

The firmware offers no pairing/auth (the ring is open to any BLE central in range), so the
"claim" is enforced in our app:
- First successful connect records the peripheral's CoreBluetooth `identifier` (per-phone
  stable `UUID`) + advertised name into `RingSyncMeta`.
- After binding, the scan still *discovers* via `RingScanMatcher`, but only **connects** to the
  bound `identifier` — a second R09 nearby is ignored.
- **"Forget ring"** control in `ProfileView` clears the binding (and optionally its data).
- Honest framing in the UI/About: this is app-level, not cryptographic; anyone in BLE range
  can still read the ring with other software. Documented, not hidden.

### 5. UI wiring — replacing the mock

- Introduce a **`HealthData` provider protocol** with the same surface the screens already
  call (`dayMetrics(for:)`, `hrvSeries(days:)`, `restingHRSeries(days:)`, `stepsSeries(days:)`,
  `sleepScoreSeries(days:)`, `strainSeries(days:)`, `sleepSession(for:)`, `hrZones(for:)`, …).
- `MockHealthData` conforms to it (kept for SwiftUI previews and tests).
- New `RingHealthData` conforms by reading SwiftData, keyed by `displayDate` so day-swiping
  shows real per-day data. Deferred metrics return `nil`/placeholder.
- Screens currently new-up `MockHealthData()` inline (e.g. `StrainView`, `RecoveryView`,
  `SleepView`, `OverviewView`). Replace those inline constructions with the provider injected
  through the environment; previews inject `MockHealthData`, the app injects `RingHealthData`.
- `DayMetrics` gains optionality (or a companion "availability" notion) so a metric with no
  source renders "—" instead of `0`. The deferred fields read as unavailable this slice.

## Error handling

- Per-metric / per-day failures are logged via the existing `trace()` and skipped; the session
  persists all successes and always disconnects.
- A day that returns empty/zero packets (beyond retention) is treated as "no data", not an
  error, and marked synced so we don't refetch it forever.
- Bluetooth-unavailable / ring-not-found / not-bound surface as existing user-facing states.
- Re-entrancy guard on `sync()` prevents overlapping sessions (cold-launch + foreground +
  periodic), as `refreshBattery` does now.

## Testing

- **Unit (Mac/CI):** every command builder + paged parser against synthetic fixtures, including
  malformed/short packets, error subtype `255`, multi-page boundaries, checksum validation, and
  BCD/Unix timestamp round-trips. Daily-aggregation logic. Ring-binding match logic.
- **Mock transport:** extended to answer the new opcodes deterministically so the simulator and
  the existing flow tests still exercise `sync()` end-to-end.
- **On-device (manual, as before):** BLE-bound behavior verified via `trace()` logs (raw hex of
  each command/response), confirming real packet layouts match the encoded assumptions — the
  same bring-up loop that validated battery. Any layout that differs is a localized parser fix.

## Out of scope (explicitly)

- Derived metrics algorithms (recovery, strain, HRV proxy, resting HR, sleep performance) —
  slice 3.
- Body-temperature decoding — pending the reverse-engineering effort.
- Respiratory-rate / raw-PPG extraction — future slice.
- macOS companion changes beyond what it already renders from synced data.
- Background BLE / `AccessorySetupKit` pairing.

## Open questions / assumptions

- **7-day retention** is empirical, not protocol-guaranteed; we cap the backfill at 7 days and
  stop at the first empty day.
- SpO2 and stress historical layouts are reverse-engineered (Gadgetbridge), so on-device
  verification may require a parser tweak — accounted for by the bring-up log loop.
