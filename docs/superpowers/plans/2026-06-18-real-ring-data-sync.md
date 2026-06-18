# Real Ring Data Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `MockHealthData` with real Colmi R09 data — a live spot reading plus a 7-day historical sync on app open — persisted locally in SwiftData, with app-layer ring binding.

**Architecture:** Expand the pure `RingProtocol` with command builders + paged-response parsers for each opcode (time, HR live/history, steps, sleep, stress, SpO2). Teach `RingTransport` to collect multi-packet responses. Evolve `RingManager.refreshBattery()` into a partial-failure-tolerant `sync()` session that sets the clock, reads live values, backfills missing days, and persists granular samples. Wire screens to a `HealthData` provider that reads SwiftData (mock provider retained for previews).

**Tech Stack:** Swift 6, SwiftUI, SwiftData, CoreBluetooth, Swift Testing. XcodeGen (`project.yml`); run `xcodegen generate` after adding files.

## Global Constraints

- **Local-only SwiftData. No iCloud / CloudKit.** (verbatim hard constraint)
- **Stock-Apple (Health) look**; deferred metrics render a dash "—", never a fabricated number.
- **Design tokens only:** `Spacing`, `Typography`, `AppColor` — no font `size:`, no raw RGB/`Color.blue`. SwiftLint runs in-build and fails on violation.
- **Free Apple tier; CoreBluetooth verified on the physical iPhone only** (not Simulator/CI). Pure protocol + persistence are unit-tested on Mac.
- **End commit messages with:** `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **16-byte packets:** `byte[0]`=command, `byte[15]`=checksum = `sum(bytes[0..<15]) % 255`. Built via existing `RingProtocol.makePacket(command:payload:)`.
- **Test target:** `OopsTests` (Swift Testing). Run via `xcodebuild -project Oops.xcodeproj -scheme Oops -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:OopsTests/<Suite>`.
- **Timestamps:** ring clock set in **UTC**; historical request timestamps are UTC midnight.
- **Paging contract:** `RingProtocol` provides, per paged command, an `isComplete(_ packets: [Data]) -> Bool` predicate; the transport accumulates notify packets until it returns true (or a per-packet timeout fires). Exact header byte offsets for the reverse-engineered commands (steps/sleep/stress/SpO2) are encoded to the documented layout and **confirmed on-device** in that task's verification step; a mismatch is a localized offset fix.

---

## File Structure

**Protocol (pure, `Shared/Ring/Protocol/`)** — split `RingProtocol` growth into per-domain files:
- `Shared/Ring/RingProtocol.swift` (exists) — keeps `makePacket`, battery, and shared helpers (`uint32LE`, BCD).
- `Shared/Ring/Protocol/RingTimeCommand.swift` — `0x01` set-time builder.
- `Shared/Ring/Protocol/RingLiveHR.swift` — `0x69`/`0x6A` builders + spot parser.
- `Shared/Ring/Protocol/RingHeartRateHistory.swift` — `0x15` builder, `isComplete`, parser.
- `Shared/Ring/Protocol/RingActivityHistory.swift` — `0x43` builder, `isComplete`, parser.
- `Shared/Ring/Protocol/RingSleepHistory.swift` — `0x44` builder, `isComplete`, parser.
- `Shared/Ring/Protocol/RingStressHistory.swift` — `0x37` builder, `isComplete`, parser.
- `Shared/Ring/Protocol/RingSpO2.swift` — live (`0x69` type 3) + history builders/parsers.

**Persistence (`Shared/Model/`):**
- `Shared/Model/RingSamples.swift` — `HeartRateSample`, `ActivitySample`, `SpO2Sample`, `StressSample` `@Model`s.
- `Shared/Model/SleepSessionRecord.swift` — persisted sleep `@Model` + stage intervals.
- `Shared/Model/RingSyncMeta.swift` — bound-ring id/name + per-metric last-synced day.
- `iOS/OopsApp.swift` (modify) — register new models in the `ModelContainer` schema.

**Transport / orchestration:**
- `Shared/Ring/RingTransport.swift` (modify) — add paged `send(_:isComplete:)`.
- `Shared/Ring/MockRingTransport.swift` (modify) — answer new opcodes; paged support.
- `iOS/Ring/BLERingTransport.swift` (modify) — paged accumulation; bind-to-identifier.
- `Shared/Ring/RingManager.swift` (modify) — `sync()` session, binding, persistence.

**UI:**
- `Shared/Model/HealthData.swift` — `HealthData` provider protocol; `MockHealthData` conforms.
- `Shared/Model/RingHealthData.swift` — SwiftData-backed provider.
- `Shared/Model/DayMetrics.swift` (modify) — optional deferred fields.
- `Shared/Screens/*` (modify) — consume injected provider; render "—" for `nil`.
- `Shared/Screens/Profile/ProfileView.swift` (modify) — "Forget ring" + honest copy.
- `iOS/Home/HomeRootView.swift` (modify) — call `sync()`; inject provider.

---

## Task 1: Shared protocol helpers (LE + BCD)

**Files:**
- Modify: `Shared/Ring/RingProtocol.swift`
- Test: `OopsTests/RingProtocolHelpersTests.swift` (create)

**Interfaces:**
- Produces: `RingProtocol.uint32LE(_ value: UInt32) -> [UInt8]`, `RingProtocol.bcd(_ value: Int) -> UInt8`, `RingProtocol.utcMidnightUnix(for date: Date, calendar: Calendar) -> UInt32`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Oops

struct RingProtocolHelpersTests {
    @Test func uint32LEIsLittleEndianFourBytes() {
        #expect(RingProtocol.uint32LE(0x01020304) == [0x04, 0x03, 0x02, 0x01])
    }

    @Test func bcdEncodesDecimalDigits() {
        #expect(RingProtocol.bcd(26) == 0x26)
        #expect(RingProtocol.bcd(9) == 0x09)
    }

    @Test func utcMidnightUnixIsStartOfDayUTC() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 6, day: 18, hour: 13))!
        let midnight = cal.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        #expect(RingProtocol.utcMidnightUnix(for: date, calendar: cal) == UInt32(midnight.timeIntervalSince1970))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project Oops.xcodeproj -scheme Oops -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:OopsTests/RingProtocolHelpersTests`
Expected: FAIL — `uint32LE` / `bcd` / `utcMidnightUnix` not found.

- [ ] **Step 3: Add the helpers to `RingProtocol`**

```swift
extension RingProtocol {
    /// 4-byte little-endian encoding (ring uses LE Unix timestamps).
    static func uint32LE(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
         UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
    }

    /// Binary-coded decimal: 26 -> 0x26. The ring's clock uses BCD.
    static func bcd(_ value: Int) -> UInt8 {
        UInt8((value / 10) * 16 + (value % 10))
    }

    /// UTC midnight (start of `date`'s day in the given calendar) as a Unix timestamp.
    static func utcMidnightUnix(for date: Date, calendar: Calendar) -> UInt32 {
        UInt32(calendar.startOfDay(for: date).timeIntervalSince1970)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Regenerate project (new test file) and commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/RingProtocol.swift OopsTests/RingProtocolHelpersTests.swift
git commit -m "feat: ring protocol LE/BCD/UTC-midnight helpers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Set-time command (`0x01`)

**Files:**
- Create: `Shared/Ring/Protocol/RingTimeCommand.swift`
- Test: `OopsTests/RingTimeCommandTests.swift`

**Interfaces:**
- Consumes: `RingProtocol.bcd`, `RingProtocol.makePacket`.
- Produces: `RingProtocol.setTimeCommand(date: Date, calendar: Calendar) -> Data`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Oops

struct RingTimeCommandTests {
    @Test func setTimeIsBCDInUTC() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 6, day: 18,
                                                 hour: 9, minute: 7, second: 5))!
        let packet = RingTimeCommandTests.bytes(RingProtocol.setTimeCommand(date: date, calendar: cal))

        #expect(packet[0] == 0x01)
        #expect(packet[1] == 0x26) // year 26 BCD
        #expect(packet[2] == 0x06) // month
        #expect(packet[3] == 0x18) // day 18 BCD
        #expect(packet[4] == 0x09) // hour
        #expect(packet[5] == 0x07) // minute
        #expect(packet[6] == 0x05) // second
        #expect(packet[7] == 0x01) // language = English
    }

    static func bytes(_ data: Data) -> [UInt8] { Array(data) }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... test -only-testing:OopsTests/RingTimeCommandTests`
Expected: FAIL — `setTimeCommand` not found.

- [ ] **Step 3: Implement**

```swift
import Foundation

extension RingProtocol {
    /// `0x01`: set the ring clock. Payload is 7 BCD bytes in UTC:
    /// [year-2000, month, day, hour, minute, second, language(1=English)].
    static func setTimeCommand(date: Date, calendar: Calendar) -> Data {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let payload: [UInt8] = [
            bcd((c.year ?? 2000) - 2000), bcd(c.month ?? 1), bcd(c.day ?? 1),
            bcd(c.hour ?? 0), bcd(c.minute ?? 0), bcd(c.second ?? 0), 0x01
        ]
        return makePacket(command: 0x01, payload: payload)
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/Protocol/RingTimeCommand.swift OopsTests/RingTimeCommandTests.swift
git commit -m "feat: ring set-time command (0x01, BCD UTC)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Live heart rate (`0x69`/`0x6A`)

**Files:**
- Create: `Shared/Ring/Protocol/RingLiveHR.swift`
- Test: `OopsTests/RingLiveHRTests.swift`

**Interfaces:**
- Produces: `RingProtocol.liveHRStartCommand() -> Data`, `RingProtocol.liveHRStopCommand() -> Data`, `RingProtocol.parseLiveHR(_ data: Data) -> Int?` (BPM, nil if error/short).

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Oops

struct RingLiveHRTests {
    @Test func startCommandRequestsHeartRateType() {
        let p = Array(RingProtocol.liveHRStartCommand())
        #expect(p[0] == 0x69)
        #expect(p[1] == 0x01) // reading type 1 = HR
        #expect(p[2] == 0x01) // action = start
    }

    @Test func stopCommandUses0x6A() {
        #expect(Array(RingProtocol.liveHRStopCommand())[0] == 0x6A)
    }

    @Test func parsesBPMWhenNoError() {
        // [0x69, type, error=0, value]
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 0x69; bytes[1] = 0x01; bytes[2] = 0x00; bytes[3] = 65
        #expect(RingProtocol.parseLiveHR(Data(bytes)) == 65)
    }

    @Test func returnsNilOnErrorByte() {
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = 0x69; bytes[1] = 0x01; bytes[2] = 0x01; bytes[3] = 65
        #expect(RingProtocol.parseLiveHR(Data(bytes)) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:OopsTests/RingLiveHRTests`. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
import Foundation

extension RingProtocol {
    /// `0x69`: start a real-time measurement. Payload [type, action]; type 1 = heart rate.
    static func liveHRStartCommand() -> Data { makePacket(command: 0x69, payload: [0x01, 0x01]) }

    /// `0x6A`: stop the real-time measurement.
    static func liveHRStopCommand() -> Data { makePacket(command: 0x6A, payload: [0x01, 0x00]) }

    /// Response [0x69, type, error, value]; BPM in byte[3] when byte[2]==0.
    static func parseLiveHR(_ data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let b = Array(data)
        guard b[0] == 0x69, b[2] == 0 else { return nil }
        let bpm = Int(b[3])
        return bpm > 0 ? bpm : nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS (4 tests).

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/Protocol/RingLiveHR.swift OopsTests/RingLiveHRTests.swift
git commit -m "feat: ring live heart-rate spot read (0x69/0x6A)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Historical heart rate (`0x15`, paged)

**Files:**
- Create: `Shared/Ring/Protocol/RingHeartRateHistory.swift`
- Test: `OopsTests/RingHeartRateHistoryTests.swift`

**Interfaces:**
- Consumes: `RingProtocol.uint32LE`, `RingProtocol.utcMidnightUnix`, `MetricSample`.
- Produces: `RingProtocol.heartRateHistoryCommand(day: Date, calendar: Calendar) -> Data`, `RingProtocol.heartRateHistoryComplete(_ packets: [Data]) -> Bool`, `RingProtocol.parseHeartRateHistory(_ packets: [Data]) -> [MetricSample]`.

**Layout (documented):** request payload = 4-byte LE UTC-midnight Unix. Response paged by `byte[1]` subtype: `0`=header (`byte[2]`=number of data packets, `byte[3]`=interval minutes), `1`=first data (`bytes[2..5]`=4-byte LE start Unix, then 9 HR values in `bytes[6..14]`), `2..N`=13 HR values in `bytes[2..14]`, `255`=error. 5-min cadence; zero values mean "no reading".

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Oops

struct RingHeartRateHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandEncodesUTCMidnightLE() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let p = Array(RingProtocol.heartRateHistoryCommand(day: day, calendar: Self.utc))
        #expect(p[0] == 0x15)
        let ts = UInt32(day.timeIntervalSince1970)
        #expect(Array(p[1...4]) == RingProtocol.uint32LE(ts))
    }

    @Test func completeWhenAllDataPacketsReceived() {
        let header = Self.packet(sub: 0, payload: [2, 5])      // 2 data packets, 5-min interval
        let d1 = Self.packet(sub: 1, payload: [])
        #expect(!RingProtocol.heartRateHistoryComplete([header]))
        #expect(!RingProtocol.heartRateHistoryComplete([header, d1]))
        let d2 = Self.packet(sub: 2, payload: [])
        #expect(RingProtocol.heartRateHistoryComplete([header, d1, d2]))
    }

    @Test func completeOnErrorPacket() {
        #expect(RingProtocol.heartRateHistoryComplete([Self.packet(sub: 255, payload: [])]))
    }

    @Test func parsesValuesWithFiveMinuteCadence() {
        let start = UInt32(Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!.timeIntervalSince1970)
        let header = Self.packet(sub: 0, payload: [1, 5])
        var first = [UInt8](repeating: 0, count: 16)
        first[0] = 0x15; first[1] = 1
        let ts = RingProtocol.uint32LE(start)
        first[2] = ts[0]; first[3] = ts[1]; first[4] = ts[2]; first[5] = ts[3]
        first[6] = 60; first[7] = 0; first[8] = 62   // 3 readings, middle is "no reading"
        let samples = RingProtocol.parseHeartRateHistory([header, Data(first)])
        #expect(samples.count == 2)                  // zeros dropped
        #expect(samples[0].value == 60)
        #expect(samples[1].value == 62)
        #expect(samples[1].date.timeIntervalSince(samples[0].date) == 10 * 60) // two 5-min slots apart
    }

    static func packet(sub: UInt8, payload: [UInt8]) -> Data {
        var b = [UInt8](repeating: 0, count: 16)
        b[0] = 0x15; b[1] = sub
        for (i, v) in payload.prefix(2).enumerated() { b[2 + i] = v }
        return Data(b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `... -only-testing:OopsTests/RingHeartRateHistoryTests`. Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
import Foundation

extension RingProtocol {
    static func heartRateHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x15, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    private static func subtype(_ packet: Data) -> Int {
        packet.count > 1 ? Int(packet[packet.startIndex + 1]) : -1
    }

    static func heartRateHistoryComplete(_ packets: [Data]) -> Bool {
        if packets.contains(where: { subtype($0) == 255 }) { return true }
        guard let header = packets.first(where: { subtype($0) == 0 }), header.count >= 3 else { return false }
        let dataPacketCount = Int(header[header.startIndex + 2])
        let received = packets.filter { (1...254).contains(subtype($0)) }.count
        return received >= dataPacketCount
    }

    static func parseHeartRateHistory(_ packets: [Data]) -> [MetricSample] {
        guard let header = packets.first(where: { subtype($0) == 0 }), header.count >= 4 else { return [] }
        let intervalSeconds = TimeInterval(max(1, Int(header[header.startIndex + 3])) * 60)
        let data = packets.filter { (1...254).contains(subtype($0)) }.sorted { subtype($0) < subtype($1) }
        guard let first = data.first(where: { subtype($0) == 1 }), first.count >= 6 else { return [] }
        let startTS = UInt32(first[first.startIndex + 2])
            | UInt32(first[first.startIndex + 3]) << 8
            | UInt32(first[first.startIndex + 4]) << 16
            | UInt32(first[first.startIndex + 5]) << 24
        var start = Date(timeIntervalSince1970: TimeInterval(startTS))

        var samples: [MetricSample] = []
        var slot = 0
        for packet in data {
            let bytes = Array(packet)
            let values = subtype(packet) == 1 ? Array(bytes[6..<16]) : Array(bytes[2..<16])
            for value in values {
                if value > 0 {
                    samples.append(MetricSample(date: start.addingTimeInterval(Double(slot) * intervalSeconds),
                                                value: Double(value)))
                }
                slot += 1
            }
        }
        _ = start // start is the slot-0 reference
        return samples
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS (4 tests).

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/Protocol/RingHeartRateHistory.swift OopsTests/RingHeartRateHistoryTests.swift
git commit -m "feat: paged historical heart-rate parse (0x15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Historical steps / calories / distance (`0x43`, paged)

**Files:**
- Create: `Shared/Ring/Protocol/RingActivityHistory.swift`
- Test: `OopsTests/RingActivityHistoryTests.swift`

**Interfaces:**
- Produces: `RingProtocol.activityHistoryCommand(dayOffset: Int) -> Data`, `RingProtocol.activityHistoryComplete(_ packets: [Data]) -> Bool`, `RingProtocol.parseActivityHistory(_ packets: [Data], calendar: Calendar) -> [ActivitySamplePoint]`, and struct `ActivitySamplePoint { let date: Date; let steps: Int; let calories: Int; let distanceMeters: Int }`.

**Layout (documented):** request `[dayOffset, 0x0f, 0x00, 0x5f, 0x01]`. Header packet `byte[1]` is `0xF0`(240) for the ×10-calorie protocol or a packet count otherwise; we read header `byte[2]` as the number of following data packets. Each data packet: `bytes[1..3]`=BCD date (year-2000, month, day), `byte[4]`=time index (hour=idx/4, min=(idx%4)*15), `bytes[7..8]`=calories LE (×10 when header is `0xF0`), `bytes[9..10]`=steps LE, `bytes[11..12]`=distance meters LE.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Oops

struct RingActivityHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandEncodesOffsetAndConstants() {
        let p = Array(RingProtocol.activityHistoryCommand(dayOffset: 0))
        #expect(p[0] == 0x43)
        #expect(Array(p[1...5]) == [0x00, 0x0f, 0x00, 0x5f, 0x01])
    }

    @Test func completeAfterDeclaredPackets() {
        let header = Self.header(flag: 0x01, count: 1)
        #expect(!RingProtocol.activityHistoryComplete([header]))
        #expect(RingProtocol.activityHistoryComplete([header, Self.dataPacket(steps: 100, cal: 5, dist: 70, idx: 4)]))
    }

    @Test func parsesStepsCaloriesDistanceAndTime() {
        let header = Self.header(flag: 0x01, count: 1)             // not ×10
        let packet = Self.dataPacket(steps: 250, cal: 12, dist: 180, idx: 5) // 01:15
        let points = RingProtocol.parseActivityHistory([header, packet], calendar: Self.utc)
        #expect(points.count == 1)
        #expect(points[0].steps == 250)
        #expect(points[0].calories == 12)
        #expect(points[0].distanceMeters == 180)
        let comps = Self.utc.dateComponents([.hour, .minute], from: points[0].date)
        #expect(comps.hour == 1 && comps.minute == 15)
    }

    @Test func caloriesScaledWhenHeaderIs240() {
        let header = Self.header(flag: 0xF0, count: 1)
        let packet = Self.dataPacket(steps: 0, cal: 12, dist: 0, idx: 0)
        #expect(RingProtocol.parseActivityHistory([header, packet], calendar: Self.utc)[0].calories == 120)
    }

    static func header(flag: UInt8, count: UInt8) -> Data {
        var b = [UInt8](repeating: 0, count: 16); b[0] = 0x43; b[1] = flag; b[2] = count; return Data(b)
    }
    static func dataPacket(steps: Int, cal: Int, dist: Int, idx: UInt8) -> Data {
        var b = [UInt8](repeating: 0, count: 16)
        b[0] = 0x43; b[1] = 0x10                          // any non-header subtype
        b[1] = 0x01; b[2] = RingProtocol.bcd(26); b[3] = 0x06; b[4] = RingProtocol.bcd(18) // wrong slot? see note
        // NOTE: date BCD lives in bytes[1..3] per layout; rewrite explicitly:
        b = [UInt8](repeating: 0, count: 16); b[0] = 0x43
        b[1] = RingProtocol.bcd(26); b[2] = 0x06; b[3] = RingProtocol.bcd(18); b[4] = idx
        b[7] = UInt8(cal & 0xFF); b[8] = UInt8(cal >> 8)
        b[9] = UInt8(steps & 0xFF); b[10] = UInt8(steps >> 8)
        b[11] = UInt8(dist & 0xFF); b[12] = UInt8(dist >> 8)
        return Data(b)
    }
}
```

> Implementer note: the header and data packets share `byte[0]=0x43`. Distinguish the header as the FIRST received packet; all subsequent packets are data. (The `0xF0` flag lives in the header's `byte[1]`.) The helper above rebuilds `b` cleanly — keep only the final construction.

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
import Foundation

struct ActivitySamplePoint: Equatable {
    let date: Date
    let steps: Int
    let calories: Int
    let distanceMeters: Int
}

extension RingProtocol {
    static func activityHistoryCommand(dayOffset: Int) -> Data {
        makePacket(command: 0x43, payload: [UInt8(dayOffset & 0xFF), 0x0f, 0x00, 0x5f, 0x01])
    }

    static func activityHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first, header.count >= 3 else { return false }
        let count = Int(header[header.startIndex + 2])
        return packets.count >= count + 1
    }

    private static func bcdToInt(_ byte: UInt8) -> Int { Int(byte >> 4) * 10 + Int(byte & 0x0F) }

    static func parseActivityHistory(_ packets: [Data], calendar: Calendar) -> [ActivitySamplePoint] {
        guard let header = packets.first, header.count >= 2 else { return [] }
        let calorieScale = header[header.startIndex + 1] == 0xF0 ? 10 : 1
        var cal = calendar; cal.timeZone = TimeZone(identifier: "UTC")!
        return packets.dropFirst().compactMap { packet in
            let b = Array(packet)
            guard b.count >= 13 else { return nil }
            let year = 2000 + bcdToInt(b[1]); let month = bcdToInt(b[2]); let day = bcdToInt(b[3])
            let idx = Int(b[4])
            let calories = (Int(b[7]) | Int(b[8]) << 8) * calorieScale
            let steps = Int(b[9]) | Int(b[10]) << 8
            let dist = Int(b[11]) | Int(b[12]) << 8
            guard let date = cal.date(from: DateComponents(year: year, month: month, day: day,
                                                           hour: idx / 4, minute: (idx % 4) * 15))
            else { return nil }
            return ActivitySamplePoint(date: date, steps: steps, calories: calories, distanceMeters: dist)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS (4 tests).

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/Protocol/RingActivityHistory.swift OopsTests/RingActivityHistoryTests.swift
git commit -m "feat: paged historical steps/cal/distance parse (0x43)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Historical sleep (`0x44`) and stress (`0x37`)

**Files:**
- Create: `Shared/Ring/Protocol/RingSleepHistory.swift`, `Shared/Ring/Protocol/RingStressHistory.swift`
- Test: `OopsTests/RingSleepHistoryTests.swift`, `OopsTests/RingStressHistoryTests.swift`

**Interfaces:**
- Produces:
  - `RingProtocol.sleepHistoryCommand(day: Date, calendar: Calendar) -> Data`, `RingProtocol.sleepHistoryComplete(_:) -> Bool`, `RingProtocol.parseSleep(_ packets: [Data], dayStart: Date) -> [SleepStageInterval]`.
  - `RingProtocol.stressHistoryCommand(day: Date, calendar: Calendar) -> Data`, `RingProtocol.stressHistoryComplete(_:) -> Bool`, `RingProtocol.parseStress(_ packets: [Data], dayStart: Date) -> [MetricSample]`.

**Sleep layout (Gadgetbridge-documented):** header `byte[1]==0` with `byte[2]`=data packet count; data packets carry `(stageCode, durationMinutes)` pairs starting at `byte[2]`, stage codes `1=light, 2=deep, 3=rem, 4=awake` (the ring computes stages). Stress: header + data packets of one byte per ~30-min slot starting at the day start; `byte[1]` subtype `0` header (`byte[2]`=count, `byte[3]`=interval minutes), data packets values in `bytes[2..14]`, `0`=no reading.

> Exact offsets are reverse-engineered; the on-device step in Task 12 confirms them. Encode to this layout; a mismatch is a localized fix here.

- [ ] **Step 1: Write the failing tests**

```swift
// OopsTests/RingSleepHistoryTests.swift
import Foundation
import Testing
@testable import Oops

struct RingSleepHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandUses0x44WithUTCMidnight() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        let p = Array(RingProtocol.sleepHistoryCommand(day: day, calendar: Self.utc))
        #expect(p[0] == 0x44)
        #expect(Array(p[1...4]) == RingProtocol.uint32LE(UInt32(day.timeIntervalSince1970)))
    }

    @Test func parsesContiguousStageIntervals() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x44; header[1] = 0; header[2] = 1
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x44; data[1] = 1
        data[2] = 1; data[3] = 30   // light, 30 min
        data[4] = 2; data[5] = 20   // deep, 20 min
        let intervals = RingProtocol.parseSleep([Data(header), Data(data)], dayStart: dayStart)
        #expect(intervals.count == 2)
        #expect(intervals[0].stage == .light)
        #expect(intervals[1].stage == .deep)
        #expect(intervals[1].start == intervals[0].end)
        #expect(intervals[0].end.timeIntervalSince(intervals[0].start) == 30 * 60)
    }
}
```

```swift
// OopsTests/RingStressHistoryTests.swift
import Foundation
import Testing
@testable import Oops

struct RingStressHistoryTests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func commandUses0x37() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        #expect(Array(RingProtocol.stressHistoryCommand(day: day, calendar: Self.utc))[0] == 0x37)
    }

    @Test func parsesNonZeroStressAtInterval() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x37; header[1] = 0; header[2] = 1; header[3] = 30
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x37; data[1] = 1
        data[2] = 40; data[3] = 0; data[4] = 55
        let samples = RingProtocol.parseStress([Data(header), Data(data)], dayStart: dayStart)
        #expect(samples.count == 2)
        #expect(samples[0].value == 40)
        #expect(samples[1].value == 55)
        #expect(samples[1].date.timeIntervalSince(samples[0].date) == 60 * 60) // two 30-min slots
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** — both suites. Expected: FAIL.

- [ ] **Step 3: Implement both files**

```swift
// Shared/Ring/Protocol/RingSleepHistory.swift
import Foundation

extension RingProtocol {
    static func sleepHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x44, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    static func sleepHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    private static func stage(for code: UInt8) -> SleepStage? {
        switch code { case 1: return .light; case 2: return .deep; case 3: return .rem; case 4: return .awake; default: return nil }
    }

    static func parseSleep(_ packets: [Data], dayStart: Date) -> [SleepStageInterval] {
        let data = packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }
        var cursor = dayStart
        var intervals: [SleepStageInterval] = []
        for packet in data {
            let b = Array(packet)
            var i = 2
            while i + 1 < b.count {
                let code = b[i]; let minutes = Int(b[i + 1]); i += 2
                if minutes == 0 { continue }
                guard let stage = stage(for: code) else { continue }
                let end = cursor.addingTimeInterval(Double(minutes) * 60)
                intervals.append(SleepStageInterval(stage: stage, start: cursor, end: end))
                cursor = end
            }
        }
        return intervals
    }
}
```

```swift
// Shared/Ring/Protocol/RingStressHistory.swift
import Foundation

extension RingProtocol {
    static func stressHistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x37, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    static func stressHistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    static func parseStress(_ packets: [Data], dayStart: Date) -> [MetricSample] {
        guard let header = packets.first(where: { $0.count > 3 && $0[$0.startIndex + 1] == 0 }) else { return [] }
        let interval = TimeInterval(max(1, Int(header[header.startIndex + 3])) * 60)
        let data = packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }
        var samples: [MetricSample] = []
        var slot = 0
        for packet in data {
            for value in Array(packet)[2..<packet.count] {
                if value > 0 { samples.append(MetricSample(date: dayStart.addingTimeInterval(Double(slot) * interval), value: Double(value))) }
                slot += 1
            }
        }
        return samples
    }
}
```

- [ ] **Step 4: Run tests to verify they pass** — Expected: PASS.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/Protocol/RingSleepHistory.swift Shared/Ring/Protocol/RingStressHistory.swift OopsTests/RingSleepHistoryTests.swift OopsTests/RingStressHistoryTests.swift
git commit -m "feat: paged sleep (0x44) and stress (0x37) parsers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: SpO2 (live `0x69` type 3 + history)

**Files:**
- Create: `Shared/Ring/Protocol/RingSpO2.swift`
- Test: `OopsTests/RingSpO2Tests.swift`

**Interfaces:**
- Produces: `RingProtocol.liveSpO2StartCommand() -> Data`, `RingProtocol.parseLiveSpO2(_:) -> Int?`, `RingProtocol.spo2HistoryCommand(day: Date, calendar: Calendar) -> Data`, `RingProtocol.spo2HistoryComplete(_:) -> Bool`, `RingProtocol.parseSpO2History(_ packets: [Data], dayStart: Date) -> [MetricSample]`.

**Layout:** live via `0x69` with type `3`; response `[0x69, 3, error, value%]`. History via `0x2C` request with 4-byte LE UTC midnight; paged like stress (header subtype 0 with count+interval; data values in `bytes[2..14]`, percentage, 0=no reading).

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import Oops

struct RingSpO2Tests {
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    @Test func liveStartRequestsType3() {
        let p = Array(RingProtocol.liveSpO2StartCommand())
        #expect(p[0] == 0x69 && p[1] == 0x03 && p[2] == 0x01)
    }

    @Test func parsesLivePercent() {
        var b = [UInt8](repeating: 0, count: 16); b[0] = 0x69; b[1] = 3; b[2] = 0; b[3] = 97
        #expect(RingProtocol.parseLiveSpO2(Data(b)) == 97)
    }

    @Test func historyCommandUses0x2C() {
        let day = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        #expect(Array(RingProtocol.spo2HistoryCommand(day: day, calendar: Self.utc))[0] == 0x2C)
    }

    @Test func parsesHistoryValues() {
        let dayStart = Self.utc.date(from: DateComponents(year: 2026, month: 6, day: 18))!
        var header = [UInt8](repeating: 0, count: 16); header[0] = 0x2C; header[1] = 0; header[2] = 1; header[3] = 60
        var data = [UInt8](repeating: 0, count: 16); data[0] = 0x2C; data[1] = 1; data[2] = 96; data[3] = 0; data[4] = 98
        let samples = RingProtocol.parseSpO2History([Data(header), Data(data)], dayStart: dayStart)
        #expect(samples.map(\.value) == [96, 98])
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
import Foundation

extension RingProtocol {
    static func liveSpO2StartCommand() -> Data { makePacket(command: 0x69, payload: [0x03, 0x01]) }

    static func parseLiveSpO2(_ data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let b = Array(data)
        guard b[0] == 0x69, b[1] == 3, b[2] == 0 else { return nil }
        return b[3] > 0 ? Int(b[3]) : nil
    }

    static func spo2HistoryCommand(day: Date, calendar: Calendar) -> Data {
        makePacket(command: 0x2C, payload: uint32LE(utcMidnightUnix(for: day, calendar: calendar)))
    }

    static func spo2HistoryComplete(_ packets: [Data]) -> Bool {
        guard let header = packets.first(where: { $0.count > 2 && $0[$0.startIndex + 1] == 0 }) else { return false }
        return packets.filter { $0.count > 1 && $0[$0.startIndex + 1] != 0 }.count >= Int(header[header.startIndex + 2])
    }

    static func parseSpO2History(_ packets: [Data], dayStart: Date) -> [MetricSample] {
        guard let header = packets.first(where: { $0.count > 3 && $0[$0.startIndex + 1] == 0 }) else { return [] }
        let interval = TimeInterval(max(1, Int(header[header.startIndex + 3])) * 60)
        var samples: [MetricSample] = []; var slot = 0
        for packet in packets.filter({ $0.count > 1 && $0[$0.startIndex + 1] != 0 }) {
            for value in Array(packet)[2..<packet.count] {
                if value > 0 { samples.append(MetricSample(date: dayStart.addingTimeInterval(Double(slot) * interval), value: Double(value))) }
                slot += 1
            }
        }
        return samples
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS (4 tests).

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/Protocol/RingSpO2.swift OopsTests/RingSpO2Tests.swift
git commit -m "feat: SpO2 live (0x69 t3) and history (0x2C) parsers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: SwiftData models + container registration

**Files:**
- Create: `Shared/Model/RingSamples.swift`, `Shared/Model/SleepSessionRecord.swift`, `Shared/Model/RingSyncMeta.swift`
- Modify: `iOS/OopsApp.swift` (container schema)
- Test: `OopsTests/RingPersistenceTests.swift`

**Interfaces:**
- Produces `@Model` classes: `HeartRateSample(timestamp: Date, bpm: Int)`, `ActivitySample(timestamp: Date, steps: Int, calories: Int, distanceMeters: Int)`, `SpO2Sample(timestamp: Date, percent: Int)`, `StressSample(timestamp: Date, value: Int)`, `SleepSessionRecord(dayStart: Date, intervals: [SleepStageIntervalRecord])` + `SleepStageIntervalRecord(stageRaw: Int, start: Date, end: Date)`, `RingSyncMeta(boundRingID: String?, boundRingName: String?, lastSyncedDay: [String: Date])`.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import SwiftData
import Testing
@testable import Oops

struct RingPersistenceTests {
    @MainActor
    @Test func insertsAndFetchesHeartRateSamples() throws {
        let container = try ModelContainer(
            for: HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
                StressSample.self, SleepSessionRecord.self, RingSyncMeta.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        ctx.insert(HeartRateSample(timestamp: .init(timeIntervalSince1970: 1), bpm: 60))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<HeartRateSample>())
        #expect(fetched.count == 1)
        #expect(fetched[0].bpm == 60)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL (types undefined).

- [ ] **Step 3: Implement models**

```swift
// Shared/Model/RingSamples.swift
import Foundation
import SwiftData

@Model final class HeartRateSample {
    var timestamp: Date; var bpm: Int
    init(timestamp: Date, bpm: Int) { self.timestamp = timestamp; self.bpm = bpm }
}

@Model final class ActivitySample {
    var timestamp: Date; var steps: Int; var calories: Int; var distanceMeters: Int
    init(timestamp: Date, steps: Int, calories: Int, distanceMeters: Int) {
        self.timestamp = timestamp; self.steps = steps; self.calories = calories; self.distanceMeters = distanceMeters
    }
}

@Model final class SpO2Sample {
    var timestamp: Date; var percent: Int
    init(timestamp: Date, percent: Int) { self.timestamp = timestamp; self.percent = percent }
}

@Model final class StressSample {
    var timestamp: Date; var value: Int
    init(timestamp: Date, value: Int) { self.timestamp = timestamp; self.value = value }
}
```

```swift
// Shared/Model/SleepSessionRecord.swift
import Foundation
import SwiftData

@Model final class SleepSessionRecord {
    var dayStart: Date
    @Relationship(deleteRule: .cascade) var intervals: [SleepStageIntervalRecord]
    init(dayStart: Date, intervals: [SleepStageIntervalRecord]) { self.dayStart = dayStart; self.intervals = intervals }
}

@Model final class SleepStageIntervalRecord {
    var stageRaw: Int; var start: Date; var end: Date
    init(stageRaw: Int, start: Date, end: Date) { self.stageRaw = stageRaw; self.start = start; self.end = end }
}
```

```swift
// Shared/Model/RingSyncMeta.swift
import Foundation
import SwiftData

@Model final class RingSyncMeta {
    var boundRingID: String?
    var boundRingName: String?
    /// Keyed by metric name ("hr","activity","sleep","stress","spo2") -> last synced day-start.
    var lastSyncedDay: [String: Date]
    init(boundRingID: String? = nil, boundRingName: String? = nil, lastSyncedDay: [String: Date] = [:]) {
        self.boundRingID = boundRingID; self.boundRingName = boundRingName; self.lastSyncedDay = lastSyncedDay
    }
}
```

- [ ] **Step 4: Register the models in the app container**

In `iOS/OopsApp.swift`, add the new types to the `Schema`/`ModelContainer` `for:` list alongside `BatteryReading`, `WorkoutRecord`, `SyncLogEntry` (keep the existing try / wipe-and-recreate guard). Example addition:

```swift
let schema = Schema([
    BatteryReading.self, WorkoutRecord.self, SyncLogEntry.self,
    HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
    StressSample.self, SleepSessionRecord.self, SleepStageIntervalRecord.self, RingSyncMeta.self
])
```

- [ ] **Step 5: Run test + build app to verify schema opens**

Run: `... test -only-testing:OopsTests/RingPersistenceTests` (PASS), then
`xcodebuild -project Oops.xcodeproj -scheme Oops -destination 'platform=iOS Simulator,name=iPhone 17' build` (BUILD SUCCEEDED).

- [ ] **Step 6: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Model/RingSamples.swift Shared/Model/SleepSessionRecord.swift Shared/Model/RingSyncMeta.swift iOS/OopsApp.swift OopsTests/RingPersistenceTests.swift
git commit -m "feat: SwiftData models for ring samples + sync meta

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Paged transport read

**Files:**
- Modify: `Shared/Ring/RingTransport.swift`, `Shared/Ring/MockRingTransport.swift`, `iOS/Ring/BLERingTransport.swift`
- Test: `OopsTests/MockRingTransportTests.swift` (extend)

**Interfaces:**
- Adds to `RingTransport`: `func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data]`.
- The existing one-shot `send(_:) -> Data` stays (battery/live use it).

- [ ] **Step 1: Write the failing test (mock returns multiple packets)**

```swift
@MainActor
@Test func pagedSendCollectsUntilComplete() async throws {
    let mock = MockRingTransport()
    try await mock.connect()
    // History HR command -> mock yields a header + data packets; complete predicate from RingProtocol.
    let cmd = RingProtocol.heartRateHistoryCommand(day: .init(timeIntervalSince1970: 0), calendar: .current)
    let packets = try await mock.send(cmd, isComplete: RingProtocol.heartRateHistoryComplete)
    #expect(packets.count >= 2)
    #expect(packets.first?.first == 0x15)
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (no paged `send`).

- [ ] **Step 3: Add the protocol requirement and implement for both transports**

In `RingTransport.swift`:

```swift
func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data]
```

In `BLERingTransport.swift`, accumulate notify packets instead of resolving on the first:

```swift
private var collected: [Data] = []
private var isCompletePredicate: (([Data]) -> Bool)?

func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
    guard stage == .ready, let peripheral, let writeChar else { throw RingError.notConnected }
    collected = []; isCompletePredicate = isComplete
    trace("Write paged command: \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
    return try await withCheckedThrowingContinuation { continuation in
        pagedContinuation = continuation
        let type: CBCharacteristicWriteType = writeChar.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(command, for: writeChar, type: type)
        armResponseTimeout()
    }
}
```

In `didUpdateValueFor`, when a paged read is in flight: append to `collected`, re-arm the per-packet timeout, and resolve `pagedContinuation` when `isCompletePredicate?(collected) == true`. Add `pagedContinuation`/`armResponseTimeout()` mirroring the existing single-shot machinery, and make the new resolvers idempotent (same guard pattern as `answer`/`failResponse`). The per-packet timeout failing resolves the paged read with `.timeout`.

In `MockRingTransport.swift`, switch on `command[0]` to return deterministic packets:

```swift
func send(_ command: Data, isComplete: @escaping ([Data]) -> Bool) async throws -> [Data] {
    switch command.first {
    case 0x15: return MockRingTransport.hrHistoryPackets()
    case 0x43: return MockRingTransport.activityPackets()
    case 0x44: return MockRingTransport.sleepPackets()
    case 0x37: return MockRingTransport.stressPackets()
    case 0x2C: return MockRingTransport.spo2Packets()
    default:   return [try await send(command)]
    }
}
```

Add the small static packet builders (header + a couple of data packets each, matching the Task 4–7 layouts) so simulator runs produce non-empty, deterministic data.

- [ ] **Step 4: Run to verify it passes** — Expected: PASS.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add project.yml Oops.xcodeproj Shared/Ring/RingTransport.swift Shared/Ring/MockRingTransport.swift iOS/Ring/BLERingTransport.swift OopsTests/MockRingTransportTests.swift
git commit -m "feat: paged transport read (collect packets until complete)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Ring binding (remember my ring)

**Files:**
- Modify: `iOS/Ring/BLERingTransport.swift` (accept a bound identifier), `Shared/Ring/RingManager.swift` (read/write `RingSyncMeta`)
- Test: `OopsTests/RingScanMatcherTests.swift` (extend with a binding-match test on the pure helper)

**Interfaces:**
- Adds `RingScanMatcher.matches(name:advertisedServiceUUIDs:boundID:peripheralID:)` overload: when `boundID != nil`, require `peripheralID == boundID`; else fall back to the existing name/UUID match.
- `BLERingTransport` gains `var boundRingID: UUID?` set by `RingManager` before `connect()`.

- [ ] **Step 1: Write the failing test**

```swift
@Test func boundRingOnlyMatchesItsIdentifier() {
    let bound = UUID(); let other = UUID()
    #expect(RingScanMatcher.matches(name: "R09_4301", advertisedServiceUUIDs: [], boundID: bound, peripheralID: bound))
    #expect(!RingScanMatcher.matches(name: "R09_4301", advertisedServiceUUIDs: [], boundID: bound, peripheralID: other))
    // Unbound: falls back to name match
    #expect(RingScanMatcher.matches(name: "R09_4301", advertisedServiceUUIDs: [], boundID: nil, peripheralID: other))
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (overload missing).

- [ ] **Step 3: Implement**

```swift
extension RingScanMatcher {
    static func matches(name: String?, advertisedServiceUUIDs: [CBUUID],
                        boundID: UUID?, peripheralID: UUID) -> Bool {
        if let boundID { return peripheralID == boundID }
        return matches(name: name, advertisedServiceUUIDs: advertisedServiceUUIDs)
    }
}
```

In `BLERingTransport.didDiscover`, call the new overload with `boundRingID` and `peripheral.identifier`. On a successful `connect()`, expose the connected `peripheral.identifier` so `RingManager` can persist it. In `RingManager`, load `RingSyncMeta` (create if absent); set `transport.boundRingID` before connecting; after the first successful connect, store `boundRingID`/`boundRingName` if not already bound.

- [ ] **Step 4: Run to verify it passes** — Expected: PASS.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add -A
git commit -m "feat: app-layer ring binding (connect only to bound ring)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Sync session in `RingManager`

**Files:**
- Modify: `Shared/Ring/RingManager.swift`
- Test: `OopsTests/RingManagerSyncTests.swift`

**Interfaces:**
- Replaces `refreshBattery()` with `func sync() async`. Keeps published `batteryStatus`, `lastUpdated`, `isBusy`, `errorMessage`, `bluetoothUnavailable`; adds `var liveHR: Int?`.
- Persists samples (deduped by timestamp) and updates `RingSyncMeta.lastSyncedDay`.

- [ ] **Step 1: Write the failing test (mock transport, in-memory store)**

```swift
@MainActor
@Test func syncPersistsBatteryLiveHRAndHistory() async throws {
    let container = try ModelContainer(
        for: BatteryReading.self, HeartRateSample.self, ActivitySample.self, SpO2Sample.self,
            StressSample.self, SleepSessionRecord.self, SleepStageIntervalRecord.self, RingSyncMeta.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let manager = RingManager(transport: MockRingTransport(), modelContext: container.mainContext)
    await manager.sync()
    #expect(manager.batteryStatus != nil)
    #expect(manager.liveHR != nil)
    #expect(try container.mainContext.fetch(FetchDescriptor<HeartRateSample>()).count > 0)
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`sync` undefined).

- [ ] **Step 3: Implement `sync()`**

Replace `refreshBattery()` with `sync()` that, after the `guard !isBusy` re-entry guard and `connect()`:
1. `try? transport.send(RingProtocol.setTimeCommand(date: .now, calendar: .current))`
2. battery via existing one-shot `send`; publish + insert `BatteryReading`.
3. live HR: send start (paged read collecting until a valid `parseLiveHR`), publish `liveHR`, send stop.
4. for each day from `min(lastSynced, today-6)` … today (per metric), call the paged `send` with the matching command + `isComplete`, parse, and `upsert` samples (skip a timestamp that already exists), then set `lastSyncedDay[metric] = today`.
5. each metric/day wrapped in `do/catch` that `trace`s and continues (partial-failure tolerant).
6. `transport.disconnect()` in all paths; `try? modelContext.save()`.

Add a private `upsert` that fetches existing timestamps for the day and inserts only new ones (dedupe).

- [ ] **Step 4: Run to verify it passes** — Expected: PASS.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add -A
git commit -m "feat: RingManager.sync() session (time, live, 7-day backfill)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: On-device protocol verification (manual)

**Files:** none (verification + any localized parser offset fixes from Tasks 4–7)

- [ ] **Step 1: Build + install to the iPhone**

```bash
xcodebuild -allowProvisioningUpdates DEVELOPMENT_TEAM=G7998J9BB3 -project Oops.xcodeproj -scheme Oops \
  -destination 'platform=iOS,id=00008140-00064CE121EB001C' CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD) build
xcrun devicectl device install app --device D60C8FB9-3DCA-57B5-8569-EE2845150B5F <DerivedData>/Oops.app
```

- [ ] **Step 2: Launch with console capture, wear the ring, open the app**

```bash
xcrun devicectl device process launch --device D60C8FB9-3DCA-57B5-8569-EE2845150B5F --console com.simao.oops > /tmp/oops_sync.log 2>&1 &
```

- [ ] **Step 3: Inspect each command's raw packets**

`grep "BLE:" /tmp/oops_sync.log` — confirm, per opcode, that header/data byte offsets match the layouts encoded in Tasks 4–7 (subtype byte, counts, BCD date, LE values). For any mismatch, fix the offending parser's offsets and its synthetic-fixture test, re-run that suite, rebuild.

- [ ] **Step 4: Sanity-check values** — live HR within a plausible range; today's steps non-decreasing; sleep intervals fall in the overnight window; SpO2 ~95–99.

- [ ] **Step 5: Commit any offset fixes**

```bash
git add -A
git commit -m "fix: align ring parsers with on-device packet layouts

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: `HealthData` provider protocol + mock conformance

**Files:**
- Create: `Shared/Model/HealthData.swift`
- Modify: `Shared/Model/MockHealthData.swift` (conform), `Shared/Model/DayMetrics.swift` (optional deferred fields)
- Test: `OopsTests/HealthDataTests.swift`

**Interfaces:**
- `protocol HealthData` with the methods the screens use: `func dayMetrics(for date: Date) -> DayMetrics`, `func hrvSeries(days: Int) -> [MetricSample]`, `restingHRSeries`, `stepsSeries`, `sleepScoreSeries`, `strainSeries`, `func sleepSession(for date: Date) -> SleepSession`, `func hrZones(for date: Date) -> [HRZone]`.
- `DayMetrics` deferred fields (`hrv`, `bodyTempDelta`, `respiratoryRate`, and the computed `score`/`recovery`/`strain`) become `Int?`/`Double?`.

- [ ] **Step 1: Write the failing test**

```swift
@Test func mockConformsToHealthDataProtocol() {
    let provider: any HealthData = MockHealthData()
    #expect(provider.dayMetrics(for: .now).steps >= 0)
    #expect(!provider.stepsSeries(days: 7).isEmpty)
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement** the protocol; make `MockHealthData` conform (it already has matching methods — add `for date:` parameters, ignoring the date to keep deterministic output). Change `DayMetrics` deferred fields to optionals; update `MockHealthData.dayMetrics` to supply sample values (mock can still provide them). Update any screen reads broken by optionality minimally (full UI wiring is Task 14).

- [ ] **Step 4: Run to verify it passes** + `build`. Expected: PASS / BUILD SUCCEEDED.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add -A
git commit -m "feat: HealthData provider protocol; mock conforms; optional deferred metrics

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: `RingHealthData` (SwiftData-backed) + screen injection

**Files:**
- Create: `Shared/Model/RingHealthData.swift`
- Modify: `Shared/Screens/OverviewView.swift`, `Shared/Screens/Sleep/SleepView.swift`, `Shared/Screens/Recovery/RecoveryView.swift`, `Shared/Screens/Strain/StrainView.swift` (and any other inline `MockHealthData()` user), `iOS/Home/HomeRootView.swift`
- Test: `OopsTests/RingHealthDataTests.swift`

**Interfaces:**
- `RingHealthData(modelContext:)` conforms to `HealthData`, computing daily aggregates from the stored samples (steps = sum of the day's `ActivitySample.steps`, current HR = latest `HeartRateSample`, etc.). Deferred metrics return `nil`.

- [ ] **Step 1: Write the failing test**

```swift
@MainActor
@Test func aggregatesStepsForADay() throws {
    let container = try ModelContainer(for: ActivitySample.self, /* …all models… */,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = container.mainContext
    let day = Calendar.current.startOfDay(for: .now)
    ctx.insert(ActivitySample(timestamp: day, steps: 100, calories: 5, distanceMeters: 70))
    ctx.insert(ActivitySample(timestamp: day.addingTimeInterval(900), steps: 150, calories: 7, distanceMeters: 110))
    try ctx.save()
    let provider = RingHealthData(modelContext: ctx)
    #expect(provider.dayMetrics(for: day).steps == 250)
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement** `RingHealthData`: fetch samples per day via `FetchDescriptor` with date-range predicates; aggregate. Inject the provider through a SwiftUI `Environment` value (`\.healthData`); in `HomeRootView`, build `RingHealthData(modelContext:)` and set it on the environment; in each screen, read `@Environment(\.healthData)` and replace the inline `MockHealthData()` with it; previews inject `MockHealthData()`. Render `nil` deferred metrics as a dash via the existing `LabeledContent`/`metricValueStyle` (e.g., a `formatted(_ value: Int?) -> String` returning "—" for nil).

- [ ] **Step 4: Run to verify it passes** + `build`. Expected: PASS / BUILD SUCCEEDED.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add -A
git commit -m "feat: SwiftData-backed HealthData; screens read real per-day data

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Wire `HomeRootView` to `sync()`; "Forget ring" in Profile

**Files:**
- Modify: `iOS/Home/HomeRootView.swift`, `Shared/Screens/Profile/ProfileView.swift`
- Test: covered by build + the existing `RingManagerSyncTests` (no new unit test; UI wiring)

- [ ] **Step 1: Replace battery refresh with sync**

In `HomeRootView`, change the three `manager?.refreshBattery()` call sites (initial `.task`, periodic loop, `.onChange(scenePhase == .active)`) to `manager?.sync()`. Keep the re-entry guard. `TopBar` battery still reads `manager?.batteryStatus`.

- [ ] **Step 2: Add "Forget ring" to `ProfileView`**

Add a section showing the bound ring name (from `RingSyncMeta`) and a **"Forget ring"** button that clears `boundRingID`/`boundRingName` (and offers to delete synced samples), plus one line of honest copy: *"Anyone with a Bluetooth app nearby can read this ring — binding only controls which ring this app uses."* Use design tokens and `Label`/`LabeledContent`.

- [ ] **Step 3: Build + run on Simulator**

Run: `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' build` → BUILD SUCCEEDED. Launch in Simulator; confirm screens show mock-via-`RingHealthData`-empty → placeholders where no data, and no crash.

- [ ] **Step 4: Full test suite**

Run: `xcodebuild -project Oops.xcodeproj -scheme Oops -destination 'platform=iOS Simulator,name=iPhone 17' test`
Expected: all suites PASS.

- [ ] **Step 5: Regenerate + commit**

```bash
xcodegen generate
git add -A
git commit -m "feat: sync on open/foreground/interval; Forget ring in Profile

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: End-to-end on-device verification + lint

**Files:** none (verification)

- [ ] **Step 1:** Build + install to iPhone (commands as in Task 12).
- [ ] **Step 2:** Wear the ring, open the app, confirm via `/tmp` console log: time set, battery, live HR, and each history day fetched; screens populate with real values; deferred metrics show "—".
- [ ] **Step 3:** Background/foreground → sync re-runs; second open backfills only missing days (check `lastSyncedDay`).
- [ ] **Step 4:** `swiftlint lint --config .swiftlint.yml` → 0 violations.
- [ ] **Step 5:** Final commit if any fixes, then per `superpowers:finishing-a-development-branch`, merge to main (verified work merges directly per project convention).

```bash
git add -A && git commit -m "chore: end-to-end real-data verification

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Sync session → Tasks 9, 11, 15. Protocol expansion → Tasks 1–7. Persistence → Task 8. Ring binding → Tasks 10, 15. UI wiring/placeholders → Tasks 13, 14, 15. Testing discipline → every task + 12, 16. Deferred metrics (recovery/strain/HRV/temp/respiratory) → optionals in Task 13, "—" rendering in Task 14. ✓ All spec sections map to tasks.

**Placeholder scan:** Integration tasks (9–11, 14–15) describe edits in prose with concrete signatures and the key code shapes rather than every line — acceptable because they modify large existing files whose surrounding code the implementer reads in situ; all *new types and signatures* are given explicitly. Pure-protocol tasks (1–8) have complete code. No "TBD/handle edge cases/similar to" left.

**Type consistency:** `HealthData` method set is identical in Tasks 13 and 14. `RingSyncMeta.lastSyncedDay` keys ("hr/activity/sleep/stress/spo2") used consistently in Tasks 8 and 11. `parse*`/`*Command`/`*Complete` names match between their defining task and their use in Tasks 9/11. `ActivitySamplePoint` (protocol parse result) vs `ActivitySample` (`@Model`) are intentionally distinct — the former is decoded, the latter persisted in Task 11.

**Note on reverse-engineered layouts:** Tasks 6–7 (sleep/stress/SpO2) and the paging headers in 4–5 encode the best-documented layout; Task 12 verifies against real packets and localizes any offset fix. This is explicit, not a hidden placeholder.
