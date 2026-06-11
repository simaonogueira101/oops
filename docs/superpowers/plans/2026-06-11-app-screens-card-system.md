# App Screens & Card System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full Oops UI — a reusable `Card` component, a reduced SwiftLint-enforced color palette, a staggered sleep-stage hypnogram, and the ~55-feature screen catalog — all against mock data.

**Architecture:** A dumb, composable `Card` container holds small single-purpose content blocks and Swift Charts primitives. A seeded `MockHealthData` provider feeds every screen. Pure logic (band mapping, sleep aggregation, deltas) is TDD'd in `OopsTests`; SwiftUI views are preview-driven and verified by a green build + SwiftLint. Reusable screen templates (`MetricDetailScreen`, `TrendsScreen`) keep the many vitals/trends screens DRY.

**Tech Stack:** Swift 6, SwiftUI, Swift Charts, SwiftData, XcodeGen, SwiftLint (custom design-token rules), Swift Testing.

---

## Conventions for every task

- **After adding/removing files:** run `xcodegen generate` (sources are folder globs).
- **Build (iOS):** `xcodebuild -project Oops.xcodeproj -scheme Oops -destination 'platform=iOS Simulator,name=iPhone 17' build`
- **Build (macOS, shared screens):** `xcodebuild -project Oops.xcodeproj -scheme OopsMac -destination 'platform=macOS' build`
- **Lint:** `swiftlint lint --config .swiftlint.yml` (also runs in-build; must be clean).
- **Tests:** `xcodebuild -project Oops.xcodeproj -scheme Oops -destination 'platform=iOS Simulator,name=iPhone 17' test`
- **Commit** at the end of each task with a Conventional-Commit subject, ending:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- Every new SwiftUI view ships a `#Preview` exercising light + dark.
- Use only `Spacing`/`Typography`/`AppColor` tokens — never literals (lint enforces it).

---

## File Structure

**Design system (`Shared/DesignSystem/`)**
- `AppColor.swift` (modify) — semantic tokens backed by asset colors.
- `ScoreBand.swift` (create) — score→band→color/label mapping (pure).
- `Card/Card.swift` (create) — the container + `CardAccessory`/`CardStyle`/`CardFooter`.
- `Card/CardModifiers.swift` (create) — `.cardDrawer(...)`, `ExpandableCard`.
- `Blocks/*.swift` (create) — ScoreRing, CompositeHeroRing, HeroNumber, StatTile, ContributorRows, ZoneScale, GoalProgress, Sparkline, TagChips, DeltaLabel, MediaThumbnail, CoachPrompt, PeriodPicker, DateScroller.
- `Charts/*.swift` (create) — RingChart, LineTrendChart, BarSeriesChart, SleepStageChart, WorkoutMapSnapshot.

**Model (`Shared/Model/`)**
- `HealthModels.swift` (create) — value types (MetricSample, SleepStage/Interval/Session, HRZone, Workout, etc.).
- `SleepSession+Aggregation.swift` (create) — stage %/duration math.
- `DayMetrics.swift` (move/extend from `Screens/HomeModels.swift`).
- `MockHealthData.swift` (create) — deterministic sample provider.

**Routing & screens (`Shared/Screens/`)**
- `AppRoute.swift` (create) — value-based routes.
- `OverviewView.swift` (rewrite) — Today card feed.
- `Sleep/*`, `Recovery/*`, `Strain/*`, `Vitals/*`, `Trends/*`, `Journal/*`, `Settings/*`, `Onboarding/*` (create).
- `MetricDetailScreen.swift` (create) — template for vitals.

**iOS**
- `iOS/Home/HomeRootView.swift` (modify) — per-tab `NavigationStack` + routing.

**Config**
- `.swiftlint.yml` (modify) — ban system color literals.
- `Assets.xcassets` color sets (create).
- `FEATURES.md` (create, repo root) — tracking table.

---

# Phase 1 — Color foundation

### Task 1: Score band mapping (pure, TDD)

**Files:**
- Create: `Shared/DesignSystem/ScoreBand.swift`
- Test: `OopsTests/ScoreBandTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftUI
@testable import Oops

struct ScoreBandTests {
    @Test func mapsScoreToBand() {
        #expect(ScoreBand(score: 10) == .poor)
        #expect(ScoreBand(score: 45) == .fair)
        #expect(ScoreBand(score: 70) == .good)
        #expect(ScoreBand(score: 90) == .optimal)
    }

    @Test func clampsOutOfRange() {
        #expect(ScoreBand(score: -5) == .poor)
        #expect(ScoreBand(score: 999) == .optimal)
    }

    @Test func everyBandHasLabel() {
        for band in ScoreBand.allCases {
            #expect(!band.label.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `… test -only-testing:OopsTests/ScoreBandTests` → FAIL (no `ScoreBand`).

- [ ] **Step 3: Implement**

```swift
import SwiftUI

/// Qualitative band for a 0–100 score. Drives the status color/label used across the app.
enum ScoreBand: CaseIterable {
    case poor, fair, good, optimal

    init(score: Int) {
        switch max(0, min(100, score)) {
        case ..<35: self = .poor
        case ..<60: self = .fair
        case ..<80: self = .good
        default: self = .optimal
        }
    }

    var label: String {
        switch self {
        case .poor: return "Pay attention"
        case .fair: return "Fair"
        case .good: return "Good"
        case .optimal: return "Optimal"
        }
    }

    /// Status color — reuses the semantic trio only (keeps the palette small).
    var color: Color {
        switch self {
        case .poor: return AppColor.negative
        case .fair: return AppColor.caution
        case .good, .optimal: return AppColor.positive
        }
    }
}
```

- [ ] **Step 4: Run, verify it passes.**
- [ ] **Step 5: Commit** — `feat: add ScoreBand score→band→color mapping`

---

### Task 2: Asset-catalog colors + AppColor tokens

**Files:**
- Create color sets under the iOS/macOS asset catalogs (see Step 1).
- Modify: `Shared/DesignSystem/AppColor.swift`

> **Note on asset catalogs:** confirm the catalog path first — `ls iOS/*.xcassets macOS/*.xcassets Shared/**/*.xcassets 2>/dev/null`. Add the color sets to the catalog the app target already compiles (the one holding `AppIcon`). If a shared catalog does not exist, create `Shared/Assets.xcassets` and add it to both targets' `sources` in `project.yml`, then `xcodegen generate`.

- [ ] **Step 1: Create each color set** as `<Catalog>/Colors/<Name>.colorset/Contents.json` with Any + Dark appearances. Names and hex (sRGB) from the spec §2.1:

`Recovery` (Any `#2A7FC0`, Dark `#4AA3DF`), `Sleep` (Any `#6457D6`, Dark `#7B6CF6`), `Strain`
(Any `#E8593A`, Dark `#FF7A59`), `Positive` (Any `#248A3D`, Dark `#34C759`), `Caution`
(Any `#C77F1A`, Dark `#FFB340`), `Negative` (Any `#D70015`, Dark `#FF453A`), `Background`
(Any `#F2F2F7`, Dark `#0E1116`), `Surface` (Any `#FFFFFF`, Dark `#171B22`), `SurfaceElevated`
(Any `#FFFFFF`, Dark `#1D2230`), `Separator` (Any `#E3E3E8`, Dark `#262B34`), `Track`
(Any `#E5E5EA`, Dark `#2A2F3A`).

Template `Contents.json` (substitute the two hex values, converting `#RRGGBB` to 0–1 or keeping 8-bit `"red":"0x4A"` form):

```json
{
  "colors": [
    { "idiom": "universal",
      "color": { "color-space": "srgb", "components": { "red": "0x2A", "green": "0x7F", "blue": "0xC0", "alpha": "1.000" } } },
    { "idiom": "universal", "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
      "color": { "color-space": "srgb", "components": { "red": "0x4A", "green": "0xA3", "blue": "0xDF", "alpha": "1.000" } } }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 2: Rewrite `AppColor.swift`**

```swift
import SwiftUI

/// Semantic color tokens — the app's entire palette. Backed by asset colors with light + dark
/// appearances. System color literals (Color.blue, .green, …) are banned by SwiftLint so the
/// palette stays small; use these tokens or .primary/.secondary/.tint. Cross-platform.
enum AppColor {
    // Text & system
    static let label = Color.primary
    static let secondaryLabel = Color.secondary

    // Domains
    static let recovery = Color("Recovery")
    static let sleep = Color("Sleep")
    static let strain = Color("Strain")
    static let accent = Color("Recovery") // app tint

    // Status (reused app-wide for bands, deltas, charging, errors)
    static let positive = Color("Positive")
    static let caution = Color("Caution")
    static let negative = Color("Negative")
    static let warning = Color("Caution") // back-compat alias

    // Neutrals
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let surfaceElevated = Color("SurfaceElevated")
    static let separator = Color("Separator")
    static let track = Color("Track")
}
```

- [ ] **Step 3:** `xcodegen generate` (if catalog/sources changed), then build iOS + macOS. Expected: PASS.
- [ ] **Step 4: Commit** — `feat: add adaptive asset colors and AppColor palette tokens`

---

### Task 3: Migrate existing color literals + set app tint

**Files:**
- Modify: `Shared/Screens/OverviewView.swift`, `Shared/Ring/`/views using `.green`/`.blue`, `iOS/Home/Pages.swift`, `Shared/Views/*`, `iOS/OopsApp.swift`.

- [ ] **Step 1:** Find offenders — `grep -rnE '\.(red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown)\b' Shared iOS macOS --include=*.swift`.
- [ ] **Step 2:** Replace each per the §2.2 domain map: recovery→`AppColor.recovery`, strain→`AppColor.strain`, sleep→`AppColor.sleep`; success/charging→`AppColor.positive`, error→`AppColor.negative`. In `OverviewView`, recovery/HRV stats use `.recovery`, strain/sleep stats use `.strain`/`.sleep` respectively (was green/blue).
- [ ] **Step 3:** In `iOS/OopsApp.swift` root scene, add `.tint(AppColor.accent)` and set `.background(AppColor.background)` where the root container is defined.
- [ ] **Step 4:** Build iOS + macOS. Expected: PASS (lint rule not yet added, so this is a pure refactor).
- [ ] **Step 5: Commit** — `refactor: migrate color literals to AppColor tokens`

---

### Task 4: SwiftLint — ban system color literals

**Files:**
- Modify: `.swiftlint.yml`

- [ ] **Step 1:** Add to `only_rules`: `no_system_color_literal`. Add custom rule:

```yaml
  no_system_color_literal:
    name: "No System Color Literal"
    regex: '(Color\.(red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown)\b|(foregroundStyle|foregroundColor|fill|tint|stroke|background)\(\s*\.(red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown)\b)'
    message: "Use an AppColor token (AppColor.recovery, AppColor.positive) — system color literals are banned to keep the palette small."
    severity: error
```

- [ ] **Step 2:** Run `swiftlint lint --config .swiftlint.yml`. Expected: clean (Task 3 migrated all usages). If any violation remains, fix it.
- [ ] **Step 3:** Build iOS (lint runs in build). Expected: PASS.
- [ ] **Step 4: Commit** — `feat: enforce reduced color palette via SwiftLint`

---

# Phase 2 — Domain models & mock data

### Task 5: Core health value types

**Files:**
- Create: `Shared/Model/HealthModels.swift`

- [ ] **Step 1:** Implement plain value types (no test yet; exercised by Task 6/7):

```swift
import Foundation
import SwiftUI

struct MetricSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum DeltaDirection { case up, down, flat
    var symbol: String { self == .up ? "arrow.up" : self == .down ? "arrow.down" : "minus" }
    /// Color is caller-supplied (up isn't always "good"); default positive/negative.
    func color(upIsGood: Bool = true) -> Color {
        switch self {
        case .flat: return AppColor.secondaryLabel
        case .up: return upIsGood ? AppColor.positive : AppColor.negative
        case .down: return upIsGood ? AppColor.negative : AppColor.positive
        }
    }
}

struct DeltaInfo: Equatable {
    let value: Double
    let baseline: Double
    var direction: DeltaDirection {
        if abs(value - baseline) < 0.0001 { return .flat }
        return value > baseline ? .up : .down
    }
}

enum SleepStage: String, CaseIterable, Identifiable {
    case awake, rem, light, deep
    var id: String { rawValue }
    var title: String { self == .rem ? "REM" : rawValue.capitalized }
    var color: Color {
        switch self {
        case .awake: return AppColor.strain          // attention
        case .rem:   return AppColor.sleep.opacity(0.7)
        case .light: return AppColor.recovery
        case .deep:  return AppColor.sleep
        }
    }
    /// Vertical order in the hypnogram (Awake on top → Deep at bottom).
    var row: Int { switch self { case .awake: 0; case .rem: 1; case .light: 2; case .deep: 3 } }
}

struct SleepStageInterval: Identifiable, Equatable {
    let id = UUID()
    let stage: SleepStage
    let start: Date
    let end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct HRZone: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let lowerBPM: Int
    let upperBPM: Int
    let minutes: Int
    let color: Color
}

struct Workout: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    let start: Date
    let duration: TimeInterval
    let activeCalories: Int
    let avgHR: Int
}
```

- [ ] **Step 2:** `xcodegen generate`; build iOS + macOS. Expected: PASS.
- [ ] **Step 3: Commit** — `feat: add core health value types`

---

### Task 6: Sleep aggregation (pure, TDD)

**Files:**
- Create: `Shared/Model/SleepSession.swift`
- Test: `OopsTests/SleepSessionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Oops

struct SleepSessionTests {
    private func date(_ h: Int, _ m: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 11, hour: h, minute: m))!
    }

    @Test func sumsDurationPerStage() {
        let session = SleepSession(intervals: [
            SleepStageInterval(stage: .light, start: date(0, 0), end: date(1, 0)),   // 60m
            SleepStageInterval(stage: .deep, start: date(1, 0), end: date(1, 30)),   // 30m
            SleepStageInterval(stage: .light, start: date(1, 30), end: date(2, 0)),  // 30m
            SleepStageInterval(stage: .awake, start: date(2, 0), end: date(2, 6))    // 6m
        ])
        #expect(session.duration(of: .light) == 90 * 60)
        #expect(session.duration(of: .deep) == 30 * 60)
        #expect(session.totalAsleep == 150 * 60)        // excludes awake
        #expect(session.timeInBed == 126 * 60)          // all intervals
    }

    @Test func computesPercentages() {
        let session = SleepSession(intervals: [
            SleepStageInterval(stage: .light, start: date(0, 0), end: date(3, 0)),   // 180m
            SleepStageInterval(stage: .deep, start: date(3, 0), end: date(4, 0))     // 60m
        ])
        #expect(session.percentage(of: .light) == 75)
        #expect(session.percentage(of: .deep) == 25)
        #expect(session.percentage(of: .rem) == 0)
    }
}
```

- [ ] **Step 2: Run, verify it fails** (no `SleepSession`).

- [ ] **Step 3: Implement**

```swift
import Foundation

struct SleepSession: Equatable {
    let intervals: [SleepStageInterval]

    var timeInBed: TimeInterval { intervals.reduce(0) { $0 + $1.duration } }
    var totalAsleep: TimeInterval {
        intervals.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration }
    }
    var start: Date? { intervals.map(\.start).min() }
    var end: Date? { intervals.map(\.end).max() }

    func duration(of stage: SleepStage) -> TimeInterval {
        intervals.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    /// Whole-percent of *time asleep* (awake excluded from the denominator).
    func percentage(of stage: SleepStage) -> Int {
        guard totalAsleep > 0, stage != .awake else { return 0 }
        return Int((duration(of: stage) / totalAsleep * 100).rounded())
    }
}
```

- [ ] **Step 4: Run, verify it passes.**
- [ ] **Step 5: Commit** — `feat: add SleepSession stage aggregation`

---

### Task 7: Deterministic mock data provider (TDD for determinism)

**Files:**
- Modify: move `DayMetrics` out of `Shared/Screens/HomeModels.swift` into `Shared/Model/DayMetrics.swift` (extend with `score: Int`, `hrv`, `restingHR`, `bodyTempDelta`, `respiratoryRate`, `steps`, `stepGoal`, `activeCalories`, `stress: Int`, `spo2: Int`). Keep `ProfileStore` where it is (or move to `Shared/Model/ProfileStore.swift`).
- Create: `Shared/Model/MockHealthData.swift`
- Test: `OopsTests/MockHealthDataTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Oops

struct MockHealthDataTests {
    @Test func isDeterministic() {
        let a = MockHealthData(seed: 42)
        let b = MockHealthData(seed: 42)
        #expect(a.hrvSeries(days: 7).map(\.value) == b.hrvSeries(days: 7).map(\.value))
        #expect(a.sleepSession().intervals.count == b.sleepSession().intervals.count)
    }

    @Test func sleepSessionIsContiguousAndOrdered() {
        let s = MockHealthData(seed: 1).sleepSession()
        for pair in zip(s.intervals, s.intervals.dropFirst()) {
            #expect(pair.0.end == pair.1.start)   // contiguous
        }
        #expect(s.totalAsleep > 0)
    }
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement** a seeded LCG provider. (Do **not** use `Date.now`/`Double.random`; seed everything. Use a fixed `referenceDate`.)

```swift
import Foundation

/// Deterministic sample data for every screen. Seeded so previews and tests are stable.
struct MockHealthData {
    private var rng: LCG
    let referenceDate: Date

    init(seed: UInt64 = 7) {
        rng = LCG(seed: seed)
        // Fixed reference midnight so output never depends on the wall clock.
        referenceDate = Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 0))!
    }

    // MARK: Scores
    var dayMetrics: DayMetrics {
        DayMetrics(score: 72, recovery: 0.72, strain: 8.4, hrv: 48, restingHR: 54,
                   bodyTempDelta: -0.2, respiratoryRate: 14.1, sleepPerformance: 0.86,
                   steps: 9240, stepGoal: 12000, activeCalories: 430, stress: 32, spo2: 97)
    }

    // MARK: Series
    func hrvSeries(days: Int) -> [MetricSample] { series(days: days, base: 45, spread: 18) }
    func restingHRSeries(days: Int) -> [MetricSample] { series(days: days, base: 55, spread: 6) }
    func stepsSeries(days: Int) -> [MetricSample] { series(days: days, base: 9000, spread: 4000) }

    private mutating func nextUnit() -> Double { rng.nextUnit() }
    func series(days: Int, base: Double, spread: Double) -> [MetricSample] {
        var gen = rng
        return (0..<days).reversed().map { offset in
            let jitter = (gen.nextUnit() - 0.5) * spread
            return MetricSample(date: referenceDate.addingTimeInterval(Double(-offset) * 86_400),
                                value: base + jitter)
        }
    }

    // MARK: Sleep — contiguous intervals from bedtime
    func sleepSession() -> SleepSession {
        var gen = rng
        let bedtime = referenceDate.addingTimeInterval(-1 * 3600) // 23:00 prev day-ish
        let pattern: [(SleepStage, Int)] = [
            (.awake, 6), (.light, 35), (.deep, 40), (.light, 25), (.rem, 20),
            (.light, 30), (.deep, 25), (.rem, 30), (.light, 20), (.rem, 25), (.awake, 4)
        ]
        var cursor = bedtime
        var intervals: [SleepStageInterval] = []
        for (stage, minutes) in pattern {
            let wobble = Int((gen.nextUnit() - 0.5) * 8)
            let mins = max(3, minutes + wobble)
            let end = cursor.addingTimeInterval(Double(mins) * 60)
            intervals.append(SleepStageInterval(stage: stage, start: cursor, end: end))
            cursor = end
        }
        return SleepSession(intervals: intervals)
    }

    // MARK: Zones, workouts, stress
    func hrZones() -> [HRZone] {
        [HRZone(name: "Light", lowerBPM: 95, upperBPM: 114, minutes: 38, color: AppColor.recovery),
         HRZone(name: "Moderate", lowerBPM: 115, upperBPM: 132, minutes: 17, color: AppColor.positive),
         HRZone(name: "Hard", lowerBPM: 133, upperBPM: 151, minutes: 9, color: AppColor.caution),
         HRZone(name: "Peak", lowerBPM: 152, upperBPM: 200, minutes: 3, color: AppColor.negative)]
    }
    func workouts() -> [Workout] {
        [Workout(name: "Outdoor Walk", symbol: "figure.walk", start: referenceDate.addingTimeInterval(-3 * 3600),
                 duration: 90 * 60, activeCalories: 147, avgHR: 93),
         Workout(name: "Strength", symbol: "dumbbell", start: referenceDate.addingTimeInterval(-26 * 3600),
                 duration: 45 * 60, activeCalories: 210, avgHR: 110)]
    }
    func stressSeries() -> [MetricSample] { series(days: 24, base: 1.0, spread: 1.6) }
    func suggestedTags() -> [String] { ["Caffeine", "Late meal", "Stress", "Travel", "Alcohol", "Workout", "Screen time"] }
}

/// Tiny deterministic PRNG (no Foundation randomness).
struct LCG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
```

> If `series(...)` needs to be deterministic without mutating `self`, it copies `rng` into a local `gen` (as shown). Keep that pattern.

- [ ] **Step 4: Run tests, verify pass.** Also update `DayMetrics.sample` to `MockHealthData().dayMetrics` and fix any references (`OverviewView` uses `.sample`).
- [ ] **Step 5:** `xcodegen generate`; build iOS + macOS; lint. Expected: PASS.
- [ ] **Step 6: Commit** — `feat: add deterministic MockHealthData provider`

---

# Phase 3 — The Card component

### Task 8: Card container + accessory/style/footer

**Files:**
- Create: `Shared/DesignSystem/Card/Card.swift`

- [ ] **Step 1: Implement** (pure presentation; preview is the verification):

```swift
import SwiftUI

enum CardAccessory {
    case none, chevron, learnMore
    case value(String)
    case delta(DeltaInfo, upIsGood: Bool)
    case icon(String)
    case toggle(Binding<Bool>)
}

enum CardStyle { case plain, tinted(Color) }

enum CardFooter {
    case text(String)
    case cta(title: String, action: () -> Void)
}

/// The app's one card. Header (label/title/accessory) + a content slot + optional footer, on a
/// rounded surface. Presentation only — routing is supplied by the consumer (NavigationLink,
/// .cardDrawer, ExpandableCard). Use across every screen.
struct Card<Content: View>: View {
    var label: String?
    var title: String?
    var accent: Color?
    var accessory: CardAccessory = .none
    var style: CardStyle = .plain
    var footer: CardFooter?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if label != nil || title != nil || hasHeaderAccessory {
                header
            }
            content()
            footerView
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColor.separator, lineWidth: 0.5)
        )
    }

    private var hasHeaderAccessory: Bool {
        if case .none = accessory { return false }; return true
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let label {
                    Text(label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent ?? AppColor.secondaryLabel)
                        .tracking(0.8)
                }
                if let title {
                    Text(title).font(.headline)
                }
            }
            Spacer(minLength: Spacing.xs)
            accessoryView
        }
    }

    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        case .none: EmptyView()
        case .chevron:
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        case .learnMore:
            Text("Learn more").font(.footnote.weight(.semibold)).foregroundStyle(AppColor.accent)
        case .value(let v):
            Text(v).font(.headline).foregroundStyle(AppColor.secondaryLabel)
        case .delta(let info, let upIsGood):
            DeltaLabel(info: info, upIsGood: upIsGood)
        case .icon(let name):
            Image(systemName: name).foregroundStyle(accent ?? AppColor.secondaryLabel)
        case .toggle(let binding):
            Toggle("", isOn: binding).labelsHidden()
        }
    }

    @ViewBuilder private var footerView: some View {
        switch footer {
        case .none: EmptyView()
        case .text(let s):
            Divider().overlay(AppColor.separator)
            Text(s).font(.footnote).foregroundStyle(AppColor.secondaryLabel)
        case .cta(let title, let action):
            Button(action: action) { Text(title).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.regular).tint(accent ?? AppColor.accent)
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .plain: AppColor.surface
        case .tinted(let c):
            LinearGradient(colors: [c.opacity(0.18), AppColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

#Preview("Card") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            Card(label: "Recovery", title: "Good to go", accent: AppColor.recovery,
                 accessory: .chevron, footer: .text("Higher than yesterday.")) {
                Text("72").font(.metricValue).foregroundStyle(AppColor.recovery)
            }
            Card(label: "HRV", accent: AppColor.recovery,
                 accessory: .delta(DeltaInfo(value: 48, baseline: 44), upIsGood: true)) {
                Text("48 ms").font(.title.weight(.semibold))
            }
        }.padding(Spacing.md)
    }
    .background(AppColor.background)
}
```

> `DeltaLabel` is built in Task 11; if implementing Card first, temporarily inline a `Text`. Prefer building Task 11 before this preview compiles — reorder if needed.

- [ ] **Step 2:** `xcodegen generate`; build iOS + macOS; lint. Expected: PASS.
- [ ] **Step 3: Commit** — `feat: add Card container component`

---

### Task 9: Card drawer + expandable wrappers

**Files:**
- Create: `Shared/DesignSystem/Card/CardModifiers.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

extension View {
    /// Present a bottom drawer (sheet) from a tapped card.
    func cardDrawer<DrawerContent: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> DrawerContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColor.surfaceElevated)
        }
    }
}

/// A card whose content discloses extra detail in place (Oura "Heart & stress" accordion).
struct ExpandableCard<Collapsed: View, Expanded: View>: View {
    var label: String?
    var accent: Color?
    @State private var expanded = false
    @ViewBuilder var collapsed: () -> Collapsed
    @ViewBuilder var expanded_: () -> Expanded

    var body: some View {
        Card(label: label, accent: accent,
             accessory: .icon(expanded ? "chevron.up" : "chevron.down")) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                collapsed()
                if expanded { expanded_() .transition(.opacity.combined(with: .move(edge: .top))) }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy) { expanded.toggle() } }
    }
}
```

- [ ] **Step 2:** build iOS + macOS; lint. Expected: PASS.
- [ ] **Step 3: Commit** — `feat: add card drawer and expandable wrappers`

---

# Phase 4 — Content blocks

Each block is its own file in `Shared/DesignSystem/Blocks/`, plain value-type inputs, a `#Preview`. Build + lint after each; commit per block or per small group.

### Task 10: Rings — RingChart, ScoreRing, CompositeHeroRing, GoalProgress

**Files:**
- Create: `Shared/DesignSystem/Charts/RingChart.swift`
- Create: `Shared/DesignSystem/Blocks/ScoreRing.swift`
- Create: `Shared/DesignSystem/Blocks/CompositeHeroRing.swift`
- Create: `Shared/DesignSystem/Blocks/GoalProgress.swift`
- Modify: `Shared/Screens/MetricRings.swift` → use `RingChart`.

- [ ] **Step 1: `RingChart`** (donut primitive)

```swift
import SwiftUI
import Charts

struct RingChart: View {
    var value: Double        // 0...1
    var color: Color
    var lineRatio: CGFloat = 0.82

    var body: some View {
        Chart {
            SectorMark(angle: .value("v", max(value, 0.0001)), innerRadius: .ratio(lineRatio), angularInset: 1.5)
                .cornerRadius(6).foregroundStyle(color)
            SectorMark(angle: .value("t", max(1 - value, 0.0001)), innerRadius: .ratio(lineRatio))
                .foregroundStyle(AppColor.track)
        }
        .chartLegend(.hidden)
    }
}
```

- [ ] **Step 2: `ScoreRing`** (ring + centered number/label)

```swift
import SwiftUI

struct ScoreRing: View {
    var score: Int
    var accent: Color
    var caption: String?
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            RingChart(value: Double(score) / 100, color: accent)
            VStack(spacing: 0) {
                Text("\(score)").font(.metricValue).foregroundStyle(AppColor.label).minimumScaleFactor(0.5)
                if let caption { Text(caption).font(.caption2).foregroundStyle(AppColor.secondaryLabel) }
            }
        }
        .frame(width: size, height: size)
    }
}
```

- [ ] **Step 3: `CompositeHeroRing`** (center ring + up to 4 satellite stats)

```swift
import SwiftUI

struct HeroStat: Identifiable { let id = UUID(); let value: String; let label: String; let color: Color }

struct CompositeHeroRing: View {
    var score: Int
    var accent: Color
    var leading: [HeroStat]
    var trailing: [HeroStat]

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            column(leading)
            ScoreRing(score: score, accent: accent, size: 150)
            column(trailing)
        }
    }
    private func column(_ stats: [HeroStat]) -> some View {
        VStack(spacing: Spacing.lg) {
            ForEach(stats) { s in
                VStack(spacing: Spacing.xxs) {
                    Text(s.value).font(.title3.weight(.semibold)).foregroundStyle(s.color)
                    Text(s.label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(AppColor.secondaryLabel)
                }
            }
        }.frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 4: `GoalProgress`** (ring or bar toward a target)

```swift
import SwiftUI

struct GoalProgress: View {
    var current: Double
    var goal: Double
    var accent: Color
    var unit: String
    var style: Style = .bar
    enum Style { case ring, bar }
    private var fraction: Double { goal > 0 ? min(current / goal, 1) : 0 }

    var body: some View {
        switch style {
        case .ring:
            ZStack {
                RingChart(value: fraction, color: accent)
                Text("\(Int(fraction * 100))%").font(.headline)
            }.frame(width: 96, height: 96)
        case .bar:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(Int(current)) / \(Int(goal)) \(unit)").font(.subheadline.weight(.semibold))
                ProgressView(value: fraction).tint(accent)
            }
        }
    }
}
```

- [ ] **Step 5:** Refactor `MetricRings` to draw two `RingChart`s (outer recovery `AppColor.recovery`, inner strain `AppColor.strain` at `scaleEffect(0.72)`), keeping its API.
- [ ] **Step 6:** Add `#Preview`s; build iOS + macOS; lint. Expected: PASS.
- [ ] **Step 7: Commit** — `feat: add ring blocks (RingChart, ScoreRing, CompositeHeroRing, GoalProgress)`

---

### Task 11: Text/number blocks — HeroNumber, StatTile, DeltaLabel, ContributorRows

**Files:**
- Create: `Shared/DesignSystem/Blocks/HeroNumber.swift`, `StatTile.swift`, `DeltaLabel.swift`, `ContributorRows.swift`

- [ ] **Step 1: `DeltaLabel`**

```swift
import SwiftUI

struct DeltaLabel: View {
    var info: DeltaInfo
    var upIsGood: Bool = true
    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: info.direction.symbol).font(.caption2.weight(.bold))
            Text(info.baseline, format: .number.precision(.fractionLength(0)))
                .font(.caption).foregroundStyle(AppColor.secondaryLabel)
        }
        .foregroundStyle(info.direction.color(upIsGood: upIsGood))
    }
}
```

- [ ] **Step 2: `HeroNumber`**

```swift
import SwiftUI

struct HeroNumber: View {
    var value: String
    var unit: String?
    var accent: Color = AppColor.label
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Text(value).font(.metricValue).foregroundStyle(accent)
            if let unit { Text(unit).font(.title3).foregroundStyle(AppColor.secondaryLabel) }
        }
    }
}
```

- [ ] **Step 3: `StatTile`** (compact label + value, used in grids)

```swift
import SwiftUI

struct StatTile: View {
    var label: String
    var value: String
    var accent: Color = AppColor.label
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(AppColor.secondaryLabel)
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(accent)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 4: `ContributorRows`** (label + progress + qualitative tag)

```swift
import SwiftUI

struct Contributor: Identifiable {
    let id = UUID(); let name: String; let fraction: Double; let band: ScoreBand
}

struct ContributorRows: View {
    var contributors: [Contributor]
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(contributors) { c in
                VStack(spacing: Spacing.xxs) {
                    HStack {
                        Text(c.name).font(.subheadline)
                        Spacer()
                        Text(c.band.label).font(.caption.weight(.semibold)).foregroundStyle(c.band.color)
                    }
                    ProgressView(value: c.fraction).tint(c.band.color)
                }
            }
        }
    }
}
```

- [ ] **Step 5:** `#Preview`s; build iOS + macOS; lint. Expected PASS.
- [ ] **Step 6: Commit** — `feat: add number/stat/delta/contributor blocks`

---

### Task 12: ZoneScale, Sparkline, TagChips, MediaThumbnail, CoachPrompt

**Files:**
- Create: `Shared/DesignSystem/Blocks/ZoneScale.swift`, `Sparkline.swift`, `TagChips.swift`, `MediaThumbnail.swift`, `CoachPrompt.swift`

- [ ] **Step 1: `Sparkline`** (Swift Charts line, no axes)

```swift
import SwiftUI
import Charts

struct Sparkline: View {
    var samples: [MetricSample]
    var color: Color
    var body: some View {
        Chart(samples) { s in
            LineMark(x: .value("t", s.date), y: .value("v", s.value))
                .interpolationMethod(.catmullRom).foregroundStyle(color)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 40)
    }
}
```

- [ ] **Step 2: `ZoneScale`** (zone rows + gradient legend bar)

```swift
import SwiftUI

struct ZoneScale: View {
    var zones: [HRZone]
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(zones) { z in
                HStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 3).fill(z.color).frame(width: 10, height: 10)
                    Text(z.name).font(.subheadline)
                    Spacer()
                    Text("\(z.lowerBPM)–\(z.upperBPM) bpm").font(.caption).foregroundStyle(AppColor.secondaryLabel)
                    Text("\(z.minutes)m").font(.caption.weight(.semibold)).monospacedDigit()
                }
            }
            LinearGradient(colors: zones.map(\.color), startPoint: .leading, endPoint: .trailing)
                .frame(height: 8).clipShape(Capsule())
        }
    }
}
```

- [ ] **Step 3: `TagChips`** (selectable wrap of chips)

```swift
import SwiftUI

struct TagChips: View {
    var tags: [String]
    @Binding var selected: Set<String>
    var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(tags, id: \.self) { tag in
                let on = selected.contains(tag)
                Button {
                    if on { selected.remove(tag) } else { selected.insert(tag) }
                } label: {
                    Text(tag).font(.footnote.weight(.medium))
                        .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
                        .background(on ? AppColor.accent.opacity(0.2) : AppColor.track, in: Capsule())
                        .foregroundStyle(on ? AppColor.accent : AppColor.label)
                }.buttonStyle(.plain)
            }
        }
    }
}

/// Minimal flow layout for chips (no third-party dep).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
```

- [ ] **Step 4: `MediaThumbnail`** (gradient/image + title + Learn more) and `CoachPrompt` (tappable “Ask Oops anything…” pill). Keep simple, tokens only.

```swift
import SwiftUI

struct MediaThumbnail: View {
    var title: String
    var symbol: String
    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [AppColor.recovery.opacity(0.5), AppColor.sleep.opacity(0.4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: symbol).foregroundStyle(.white))
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
        }
    }
}

struct CoachPrompt: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                Text("Ask Oops anything…").foregroundStyle(AppColor.secondaryLabel)
                Spacer()
            }
            .padding(Spacing.sm)
            .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).tint(AppColor.accent)
    }
}
```

- [ ] **Step 5:** `#Preview`s; build iOS + macOS; lint. Expected PASS.
- [ ] **Step 6: Commit** — `feat: add zone/sparkline/tag/media/coach blocks`

---

### Task 13: Navigation chrome blocks — PeriodPicker, DateScroller

**Files:**
- Create: `Shared/DesignSystem/Blocks/PeriodPicker.swift`, `DateScroller.swift`

- [ ] **Step 1: `PeriodPicker`**

```swift
import SwiftUI

enum Period: String, CaseIterable, Identifiable { case day = "Day", week = "Week", month = "Month", year = "Year"; var id: String { rawValue } }

struct PeriodPicker: View {
    @Binding var period: Period
    var body: some View {
        Picker("Period", selection: $period) {
            ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
    }
}
```

- [ ] **Step 2: `DateScroller`** (prev/today/next header)

```swift
import SwiftUI

struct DateScroller: View {
    @Binding var date: Date
    private var cal: Calendar { .current }
    var body: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 0) {
                Text(isToday ? "Today" : date.formatted(.dateTime.weekday(.wide))).font(.headline)
                Text(date.formatted(.dateTime.day().month())).font(.caption).foregroundStyle(AppColor.secondaryLabel)
            }
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right") }.disabled(isToday)
        }
        .tint(AppColor.accent)
    }
    private var isToday: Bool { cal.isDateInToday(date) }
    private func shift(_ d: Int) { if let n = cal.date(byAdding: .day, value: d, to: date) { date = n } }
}
```

- [ ] **Step 3:** `#Preview`s; build iOS + macOS; lint. Expected PASS.
- [ ] **Step 4: Commit** — `feat: add PeriodPicker and DateScroller`

---

# Phase 5 — Charts: trend, bars, sleep hypnogram

### Task 14: LineTrendChart + BarSeriesChart

**Files:**
- Create: `Shared/DesignSystem/Charts/LineTrendChart.swift`, `BarSeriesChart.swift`

- [ ] **Step 1: `LineTrendChart`** (line/area + optional dashed baseline + last-point annotation)

```swift
import SwiftUI
import Charts

struct LineTrendChart: View {
    var samples: [MetricSample]
    var color: Color
    var baseline: Double?
    var body: some View {
        Chart {
            ForEach(samples) { s in
                LineMark(x: .value("Date", s.date), y: .value("Value", s.value))
                    .interpolationMethod(.catmullRom).foregroundStyle(color)
                AreaMark(x: .value("Date", s.date), y: .value("Value", s.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
            }
            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(AppColor.secondaryLabel)
            }
            if let last = samples.last {
                PointMark(x: .value("Date", last.date), y: .value("Value", last.value)).foregroundStyle(color)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 180)
    }
}
```

- [ ] **Step 2: `BarSeriesChart`**

```swift
import SwiftUI
import Charts

struct BarSeriesChart: View {
    var samples: [MetricSample]
    var color: Color
    var body: some View {
        Chart(samples) { s in
            BarMark(x: .value("Date", s.date, unit: .day), y: .value("Value", s.value))
                .cornerRadius(4).foregroundStyle(color)
        }
        .frame(height: 160)
    }
}
```

- [ ] **Step 3:** `#Preview`s with `MockHealthData().hrvSeries(days: 14)`; build iOS + macOS; lint. PASS.
- [ ] **Step 4: Commit** — `feat: add LineTrendChart and BarSeriesChart`

---

### Task 15: SleepStageChart (staggered horizontal hypnogram)

**Files:**
- Create: `Shared/DesignSystem/Charts/SleepStageChart.swift`

- [ ] **Step 1: Implement** — horizontal `BarMark` per interval, y = stage row (Awake top), x = time range, colored per stage.

```swift
import SwiftUI
import Charts

/// Staggered horizontal hypnogram: each contiguous stage interval is a rounded bar at its stage's
/// row (Awake top → Deep bottom), so segments stagger across rows over the night.
struct SleepStageChart: View {
    var session: SleepSession
    private let order: [SleepStage] = [.awake, .rem, .light, .deep]

    var body: some View {
        Chart(session.intervals) { interval in
            BarMark(
                xStart: .value("Start", interval.start),
                xEnd: .value("End", interval.end),
                y: .value("Stage", interval.stage.title)
            )
            .cornerRadius(4)
            .foregroundStyle(interval.stage.color)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: order.map(\.title)) { value in
                AxisValueLabel { if let t = value.as(String.self) { Text(t).font(.caption2) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) {
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYScale(domain: order.map(\.title))   // fixes row order Awake→Deep
        .frame(height: 160)
    }
}

#Preview {
    SleepStageChart(session: MockHealthData().sleepSession())
        .padding().background(AppColor.background)
}
```

- [ ] **Step 2:** build iOS + macOS; lint; open preview to confirm rows render Awake→Deep, segments staggered, colors correct.
- [ ] **Step 3: Commit** — `feat: add staggered SleepStageChart hypnogram`

---

### Task 16: WorkoutMapSnapshot

**Files:**
- Create: `Shared/DesignSystem/Charts/WorkoutMapSnapshot.swift`

- [ ] **Step 1: Implement** a styled placeholder map (MapKit `Map` static region with a sample polyline overlay, or a gradient placeholder if Map unavailable on the target). Keep tokens only; height 120.

```swift
import SwiftUI
import MapKit

struct WorkoutMapSnapshot: View {
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.72, longitude: -9.14),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))))
        .disabled(true)
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 2:** build iOS + macOS; lint. PASS.
- [ ] **Step 3: Commit** — `feat: add WorkoutMapSnapshot`

---

# Phase 6 — Routing + Overview (Today)

### Task 17: AppRoute + per-tab NavigationStack

**Files:**
- Create: `Shared/Screens/AppRoute.swift`
- Modify: `iOS/Home/HomeRootView.swift`

- [ ] **Step 1: `AppRoute`**

```swift
import SwiftUI

enum AppRoute: Hashable {
    case sleep, recovery, strain
    case heartRate, hrv, spo2, stress, bodyTemp, respiratory
    case workouts, hrZones, trends, journal, settings, deviceStatus
}

@MainActor
struct RouteDestination: View {
    let route: AppRoute
    var body: some View {
        switch route {
        case .sleep: SleepView()
        case .recovery: RecoveryView()
        case .strain: StrainView()
        case .heartRate: MetricDetailScreen.heartRate()
        case .hrv: MetricDetailScreen.hrv()
        case .spo2: MetricDetailScreen.spo2()
        case .stress: MetricDetailScreen.stress()
        case .bodyTemp: MetricDetailScreen.bodyTemp()
        case .respiratory: MetricDetailScreen.respiratory()
        case .workouts: WorkoutsView()
        case .hrZones: HRZonesView()
        case .trends: TrendsScreen()
        case .journal: JournalView()
        case .settings: SettingsView()
        case .deviceStatus: DeviceStatusView()
        }
    }
}
```

- [ ] **Step 2:** Wrap each `Tab` content in `HomeRootView` in a `NavigationStack` with `.navigationDestination(for: AppRoute.self) { RouteDestination(route: $0) }`. Keep the existing top bar, banner, `.task`, and sheet logic. Pass `date` to `OverviewView` (for `DateScroller`).
- [ ] **Step 3:** build iOS (this will fail to compile until referenced screens exist). To keep the build green, implement Task 17 **together with** Tasks 18–31 stubs: create minimal `struct XView: View { var body: some View { Text("…") } }` placeholders for every referenced screen first, then flesh out in later tasks. Commit the stubs.
- [ ] **Step 4:** build iOS + macOS; lint. PASS.
- [ ] **Step 5: Commit** — `feat: add AppRoute routing + per-tab navigation stacks (screen stubs)`

---

### Task 18: Overview (Today) card feed

**Files:**
- Rewrite: `Shared/Screens/OverviewView.swift`

- [ ] **Step 1: Implement** the card feed using the blocks. Signature: `OverviewView(metrics: DayMetrics, date: Binding<Date>, battery: BatteryStatus?)`. Compose, in a `ScrollView`:
  1. `DateScroller(date:)`
  2. `CompositeHeroRing` recovery card → `NavigationLink(value: AppRoute.recovery)` (label "RECOVERY", accent `.recovery`; leading stats HRV/RHR, trailing Strain/Sleep)
  3. 2-up `LazyVGrid`: Sleep card (`ScoreRing` mini + stage sparkline → `.sleep` route) and Strain card (`HeroNumber` + bars → `.strain`)
  4. Steps `GoalProgress` card (`.strain`)
  5. Heart-rate card (`Sparkline` + "Resting 54 · now 61" → `.heartRate`)
  6. 2-up: Stress card (→ `.stress`) and SpO₂ card (→ `.spo2`)
  7. 2-up: Skin-temp card (→ `.bodyTemp`) and Respiratory card (→ `.respiratory`)
  8. Ring-battery card (reuse `battery` value → `.deviceStatus`)
  9. Coach insight card (`MediaThumbnail` or `.text` footer)
  10. Tags/journal entry card (`CoachPrompt`-style → `.journal`)
- Use `Card` for every item; tappable cards wrap in `NavigationLink`. Background `AppColor.background`.

- [ ] **Step 2:** Update `HomeRootView` to pass `metrics: MockHealthData().dayMetrics`, `date: $date`, `battery: manager?.batteryStatus`.
- [ ] **Step 3:** `#Preview` in light + dark; build iOS + macOS; lint. PASS.
- [ ] **Step 4: Commit** — `feat: build Overview Today card feed`

---

# Phase 7 — Sleep

### Task 19: SleepView (hub)

**Files:**
- Create: `Shared/Screens/Sleep/SleepView.swift` (replace the placeholder in `MetricPages.swift`; remove the old `SleepView`)

- [ ] **Step 1: Implement** a `ScrollView` of cards using `MockHealthData().sleepSession()`:
  1. Sleep-score hero `Card` (`ScoreRing` score 86, accent `.sleep`, footer insight)
  2. Hypnogram `Card` → `SleepStageChart(session:)`
  3. Stage-breakdown `Card` → for each stage a row: color swatch + title + `percentage` + formatted duration (build a small `StageBreakdown` view here)
  4. Contributors `Card` → `ContributorRows` (Efficiency/Restfulness/Latency/Timing with bands)
  5. Time-in-bed/asleep 2-up `StatTile`s in a `Card`
  6. Sleeping-HR `Card` → `LineTrendChart` (recovery color)
  7. HRV-during-sleep `Card` → `LineTrendChart`
  8. Respiratory-rate `Card` → `Sparkline`
  9. Bedtime/timing `Card` (start/end times)
  10. Sleep-trends `Card` → `NavigationLink(value: .trends)`
- [ ] **Step 2:** Remove `SleepView` from `MetricPages.swift` (keep `RecoveryView`/`StrainView` there until their tasks).
- [ ] **Step 3:** `xcodegen generate`; `#Preview`; build iOS + macOS; lint. PASS.
- [ ] **Step 4: Commit** — `feat: build Sleep screen with staggered hypnogram`

---

# Phase 8 — Recovery + Vitals (template)

### Task 20: MetricDetailScreen template

**Files:**
- Create: `Shared/Screens/MetricDetailScreen.swift`

- [ ] **Step 1: Implement** a parameterized detail screen + static factories. One template serves HRV, RHR, SpO₂, stress, body-temp, respiratory, heart-rate.

```swift
import SwiftUI

struct MetricDetailScreen: View {
    let title: String
    let accent: Color
    let unit: String
    let currentValue: String
    let baseline: Double
    let samples: [MetricSample]
    let about: String
    @State private var period: Period = .week

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                PeriodPicker(period: $period).padding(.horizontal, Spacing.md)
                Card(label: title, title: currentValue, accent: accent) {
                    LineTrendChart(samples: samples, color: accent, baseline: baseline)
                }
                Card(label: "Statistics") {
                    HStack {
                        StatTile(label: "Average", value: average, accent: accent)
                        StatTile(label: "Baseline", value: "\(Int(baseline)) \(unit)")
                    }
                }
                Card(label: "About \(title)", accessory: .learnMore, footer: .text(about)) { EmptyView() }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.background)
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
    private var average: String {
        guard !samples.isEmpty else { return "–" }
        return "\(Int(samples.map(\.value).reduce(0, +) / Double(samples.count))) \(unit)"
    }
}

extension MetricDetailScreen {
    static func hrv() -> MetricDetailScreen {
        let m = MockHealthData()
        return .init(title: "HRV", accent: AppColor.recovery, unit: "ms", currentValue: "48 ms",
                     baseline: 44, samples: m.hrvSeries(days: 14),
                     about: "Heart-rate variability reflects how recovered and adaptable your nervous system is.")
    }
    static func heartRate() -> MetricDetailScreen {
        let m = MockHealthData()
        return .init(title: "Heart Rate", accent: AppColor.recovery, unit: "bpm", currentValue: "61 bpm",
                     baseline: 54, samples: m.restingHRSeries(days: 14),
                     about: "Your resting heart rate is a window into cardiovascular health and recovery.")
    }
    static func spo2() -> MetricDetailScreen { .init(title: "Blood Oxygen", accent: AppColor.recovery, unit: "%", currentValue: "97%", baseline: 96, samples: MockHealthData().series(days: 14, base: 96, spread: 3), about: "Blood-oxygen (SpO₂) shows how well your blood carries oxygen overnight.") }
    static func stress() -> MetricDetailScreen { .init(title: "Stress", accent: AppColor.strain, unit: "", currentValue: "Low", baseline: 1, samples: MockHealthData().stressSeries(), about: "Daytime stress is estimated from heart-rate and HRV patterns.") }
    static func bodyTemp() -> MetricDetailScreen { .init(title: "Skin Temperature", accent: AppColor.recovery, unit: "°C", currentValue: "−0.2 °C", baseline: 0, samples: MockHealthData().series(days: 14, base: 0, spread: 0.8), about: "Nightly skin-temperature deviation from your baseline can flag strain or illness.") }
    static func respiratory() -> MetricDetailScreen { .init(title: "Respiratory Rate", accent: AppColor.recovery, unit: "br/min", currentValue: "14.1", baseline: 14, samples: MockHealthData().series(days: 14, base: 14, spread: 2), about: "Breaths per minute during sleep is typically stable; changes can signal strain.") }
}
```

- [ ] **Step 2:** Remove the stubs for these routes (Task 17). build iOS + macOS; lint. PASS.
- [ ] **Step 3: Commit** — `feat: add MetricDetailScreen template + vitals`

---

### Task 21: RecoveryView (hub)

**Files:**
- Create: `Shared/Screens/Recovery/RecoveryView.swift` (remove placeholder from `MetricPages.swift`)

- [ ] **Step 1: Implement** card feed:
  1. Recovery-score hero `Card` (`ScoreRing` 72, accent `.recovery`, band label via `ScoreBand(score:)`, footer insight)
  2. Contributors `Card` → `ContributorRows` (HRV balance, Resting HR, Body temp, Recovery index, Sleep balance, Activity balance)
  3. HRV `Card` (`Sparkline` + `.value`/`.delta`) → `NavigationLink(value: .hrv)`
  4. Resting-HR `Card` → `.heartRate`
  5. Body-temp `Card` → `.bodyTemp`
  6. Respiratory `Card` → `.respiratory`
  7. Recovery-trends `Card` → `.trends`
  8. Educational `Card` (`MediaThumbnail` "What is Recovery?", `.learnMore`)
- [ ] **Step 2:** `xcodegen generate`; `#Preview`; build iOS + macOS; lint. PASS.
- [ ] **Step 3: Commit** — `feat: build Recovery screen`

---

# Phase 9 — Strain + workouts

### Task 22: StrainView (hub) + HRZonesView + WorkoutsView

**Files:**
- Create: `Shared/Screens/Strain/StrainView.swift` (remove placeholder), `Shared/Screens/Strain/HRZonesView.swift`, `Shared/Screens/Strain/WorkoutsView.swift`

- [ ] **Step 1: `StrainView`** card feed:
  1. Day-strain hero `Card` (`CompositeHeroRing` or `ScoreRing` accent `.strain`)
  2. Steps/distance/calories 3-up `StatTile`s in a `Card`
  3. Activity-goal `Card` (`GoalProgress` ring, `.strain`)
  4. HR-zones `Card` (`ZoneScale`) → `NavigationLink(value: .hrZones)`
  5. Workouts `Card` (list of `MockHealthData().workouts()` rows: symbol chip + name + duration) → `.workouts`
  6. Active vs restorative `Card` (two `StatTile`s)
  7. Cardio-load `Card` (`BarSeriesChart`)
  8. VO₂max/cardio-fitness `Card` (`HeroNumber` + band)
  9. Strain-trends `Card` → `.trends`
- [ ] **Step 2: `HRZonesView`** — `PeriodPicker` + `ZoneScale` + per-zone `Card`s (name, bpm range, minutes).
- [ ] **Step 3: `WorkoutsView`** — list of workouts; each row taps to a `WorkoutDetail` inline view: `WorkoutMapSnapshot` + stat grid (time, calories, avg HR) + `LineTrendChart` HR. (Define `WorkoutDetailView` in the same file.)
- [ ] **Step 4:** `xcodegen generate`; `#Preview`s; build iOS + macOS; lint. PASS.
- [ ] **Step 5: Commit** — `feat: build Strain, HR zones, and workouts screens`

---

# Phase 10 — Cross-cutting screens

### Task 23: TrendsScreen

**Files:**
- Create: `Shared/Screens/Trends/TrendsScreen.swift`

- [ ] **Step 1: Implement** — `PeriodPicker` + a `LazyVGrid`/stack of trend `Card`s, each `label` + `LineTrendChart`/`BarSeriesChart` + avg `StatTile` + `.delta` accessory: HRV, Resting HR, Sleep efficiency, Steps, Strain, Stress. Section links to Sleep/Recovery/Activity/Stress at the bottom (`NavigationLink`).
- [ ] **Step 2:** Remove `.trends` stub. `#Preview`; build iOS + macOS; lint. PASS.
- [ ] **Step 3: Commit** — `feat: build Trends screen`

---

### Task 24: JournalView (tags + mood)

**Files:**
- Create: `Shared/Screens/Journal/JournalView.swift`

- [ ] **Step 1: Implement** — `@State var selected: Set<String>`, `@State var mood: Int`. Cards:
  1. "What's going on?" `Card` → `TagChips(tags: MockHealthData().suggestedTags(), selected: $selected)`
  2. Mood `Card` → 5 SF-symbol faces (`face.smiling` … ) as a segmented selector binding `mood`
  3. Note `Card` → `TextField` ("Add a comment", axis: .vertical)
  4. Save `Card` footer `.cta("Save entry")` (no persistence yet; mock)
- [ ] **Step 2:** Remove `.journal` stub. `#Preview`; build iOS + macOS; lint. PASS.
- [ ] **Step 3: Commit** — `feat: build Journal (tags + mood) screen`

---

### Task 25: SettingsView + DeviceStatusView + Onboarding

**Files:**
- Create: `Shared/Screens/Settings/SettingsView.swift`, `Shared/Screens/Settings/DeviceStatusView.swift`, `Shared/Screens/Onboarding/OnboardingView.swift`

- [ ] **Step 1: `SettingsView`** — a `List`/`Form` of `Card`-styled sections: Profile link, Units (toggle), Goals (step goal stepper), Notifications (toggles), Ring (link to DeviceStatus), About (build via `BuildInfo`). Tokens only.
- [ ] **Step 2: `DeviceStatusView`** — ring battery `Card` (reuse the existing `BatteryScreen` content/`ScoreRing`-style), firmware/serial mock rows, connection state, "Forget ring" CTA.
- [ ] **Step 3: `OnboardingView`** (shared, distinct from the macOS setup one) — 3 `TabView` pages (welcome, pair ring, permissions) with `headerGlyph`, a page indicator, and a "Get started" CTA. Not wired into launch flow yet (reachable from Settings for now).
- [ ] **Step 4:** Remove `.settings`/`.deviceStatus` stubs. `xcodegen generate`; `#Preview`s; build iOS + macOS; lint. PASS.
- [ ] **Step 5: Commit** — `feat: build Settings, Device status, and Onboarding screens`

---

### Task 26: Wire Profile → Settings + Overview battery card

**Files:**
- Modify: `iOS/Home/ProfileView.swift`, `Shared/Screens/OverviewView.swift`

- [ ] **Step 1:** Add a "Settings" `NavigationLink`/row in `ProfileView` to `SettingsView`. Ensure the Overview battery card reflects `manager?.batteryStatus` and routes to `.deviceStatus`.
- [ ] **Step 2:** build iOS + macOS; lint. PASS.
- [ ] **Step 3: Commit** — `feat: link Profile to Settings and device status`

---

# Phase 11 — Tracking & final verification

### Task 27: FEATURES.md

**Files:**
- Create: `FEATURES.md` (repo root)

- [ ] **Step 1: Create** the table — 4 columns **Name · Description · Designed · Implemented** — with one row per feature in spec §7 (~55 rows). Mark Designed = ✅ for all (covered by the spec), Implemented = ✅ for everything built in Tasks 18–26, ⬜ for any deferred (e.g. AI-coach prompt wired to a real backend, workout GPS from real data). Include a short legend: *Designed = specified in the design doc; Implemented = built as a navigable SwiftUI screen with mock data.*
- [ ] **Step 2:** Cross-check every screen built against a row. Commit — `docs: add FEATURES.md tracking table`

---

### Task 28: Full verification sweep

- [ ] **Step 1:** `xcodegen generate`.
- [ ] **Step 2:** `swiftlint lint --config .swiftlint.yml` → **zero violations**.
- [ ] **Step 3:** iOS build → PASS. macOS build → PASS.
- [ ] **Step 4:** `… test` → all `OopsTests` pass (ScoreBand, SleepSession, MockHealthData, plus existing protocol/manager/transport).
- [ ] **Step 5:** Manually confirm (Simulator or preview) every tab and every `AppRoute` destination renders in both light and dark with no placeholder `Text("…")` stubs remaining (`grep -rn 'Text("…")' Shared iOS` → none).
- [ ] **Step 6:** Update `CLAUDE.md` architecture notes (new `DesignSystem/Card`, `Blocks`, `Charts`, screen folders, color tokens, the new SwiftLint rule). Commit — `chore: verify build/lint/tests; document UI layer`.

---

## Self-review notes (author)

- **Spec coverage:** §2 colors → Tasks 1–4; §3 Card → Tasks 8–9; §4 blocks → Tasks 10–13; charts/§5 sleep → Tasks 14–16; §6 IA/routing → Task 17; §7 catalog → Tasks 18–26 (+27 tracking); §8 mock data → Tasks 5–7; §9 testing → TDD in Tasks 1/6/7 + Task 28; §10 phasing mirrors task order.
- **Stub strategy:** Task 17 intentionally lands placeholder screens so the project always builds; each later task replaces its stub and Task 28 asserts none remain.
- **Type consistency:** `MetricSample`, `SleepSession`, `SleepStage(.title/.color/.row)`, `DeltaInfo/DeltaDirection`, `ScoreBand(score:)`, `Contributor`, `HRZone`, `Workout`, `Period`, `AppRoute` are defined once (Tasks 1, 5, 6, 11, 13, 17) and reused with the same signatures throughout.
- **Color discipline:** every code block uses only `AppColor.*`/`.primary`/`.secondary`/`.tint`; the Task 4 lint rule is added only after Task 3 migration so the build never breaks.
