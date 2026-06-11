# Oops — App Screens & Card System Design

**Date:** 2026-06-11
**Status:** Approved for planning
**Supersedes nothing.** Extends `2026-06-11-oops-ring-app-design.md` (iteration 0). That spec
defined the transport/protocol/sync seam; this one defines the **UI layer**: a reusable card
component, a reduced color system, and the full catalog of feature screens (built today against
mock data, ready to bind to real ring data later).

## 1. Background & goals

The app currently has 4 tabs (Overview, Sleep, Recovery, Strain). Overview is two concentric
green/blue rings + stats; the other three are empty `ContentUnavailableView` placeholders. There
is no shared card component, and colors are raw `.green`/`.blue` scattered across views.

This project builds out **all the screens for the feature set we want long-term**, modeled on
Whoop and Oura but rendered in a **stock-Apple (Apple Health) style** — per the hard constraint,
never Whoop chrome. Everything is built with **mock data**; no ring hardware or HealthKit is
required. When the ring lands, screens bind to real readings with no structural change.

**Goals**
- A single extensible **`Card`** component used across the entire app.
- A **staggered horizontal sleep-stage chart** (hypnogram) for Sleep.
- A **reduced, named color palette** (Oura warm dark + light), **enforced by SwiftLint**.
- A complete **screen catalog** (~55 features) tracked in `FEATURES.md`.

**Non-goals (unchanged constraints)**
- No iCloud/CloudKit. Local-only SwiftData.
- No real Bluetooth/HealthKit work here — screens use mock/sample data.
- No Whoop-style dark-only chrome; we stay Apple-native and support light + dark.

## 2. Color system

Oura-inspired **warm dark, with a light variant** (system-adaptive, dark-first). Reduced to a
fixed, named set — **6 hues + neutrals** — replacing today's ad-hoc colors.

### 2.1 Tokens

All colors are defined as **asset-catalog color sets with Any (light) + Dark appearances**, so
they adapt automatically. They are exposed through `AppColor` (extending the existing enum):

| Token | Role | Dark | Light |
|---|---|---|---|
| `AppColor.recovery` | Recovery/readiness domain; **also the app accent/tint** | `#4AA3DF` | `#2A7FC0` |
| `AppColor.sleep` | Sleep domain | `#7B6CF6` | `#6457D6` |
| `AppColor.strain` | Strain/activity domain | `#FF7A59` | `#E8593A` |
| `AppColor.positive` | good / up-delta / charging / success | `#34C759` | `#248A3D` |
| `AppColor.caution` | pay-attention / mid band | `#FFB340` | `#C77F1A` |
| `AppColor.negative` | poor / down-delta / error | `#FF453A` | `#D70015` |
| `AppColor.background` | app background | `#0E1116` | `#F2F2F7` |
| `AppColor.surface` | card surface | `#171B22` | `#FFFFFF` |
| `AppColor.surfaceElevated` | drawers, nested cards | `#1D2230` | `#FFFFFF` |
| `AppColor.label` | primary text | system `.primary` |
| `AppColor.secondaryLabel` | secondary text | system `.secondary` |
| `AppColor.separator` | hairlines / borders | `#262B34` | `#E3E3E8` |
| `AppColor.track` | unfilled ring/bar track | `#2A2F3A` | `#E5E5EA` |

The accent (`recovery` blue) is set as the SwiftUI `.tint` at the app root, replacing
`Color.accentColor` defaults. Domain colors are the **primary score color** within each domain
(Oura model: the score takes its domain hue, not a separate red/amber/green scale). The
positive/caution/negative trio is reused app-wide for **status bands, deltas, charging, and
errors only** — keeping the count low.

### 2.2 Domain → color map

- Recovery, Readiness, HRV, Resting HR, Heart Rate, SpO₂, Respiratory, Body Temp → `recovery`
- Sleep, sleep stages, bedtime → `sleep` (with per-stage shades, see §5)
- Strain, Activity, Steps, Calories, Workouts, Stress → `strain`

### 2.3 SwiftLint enforcement

Add a custom rule (severity error) to `.swiftlint.yml` that **bans SwiftUI system color
literals** so only palette tokens compile:

- Forbid `Color.<systemColor>` and bare `.<systemColor>` used as a style, where systemColor ∈
  `{red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown}`.
- Keep allowed: `.primary`, `.secondary`, `.tint`, `Color.clear`, `Color.white`/`.black` only
  where unavoidable (prefer tokens), and all `AppColor.*` / `Color("…")` asset lookups.
- The existing RGB/`#colorLiteral`/UIColor rules stay.

Message: *"Use an AppColor token (AppColor.recovery, AppColor.surface) — system color literals
are banned to keep the palette small."* Migrate existing `.green`/`.blue` in `OverviewView` and
`MetricRings` to tokens as part of this work so the build stays green.

## 3. The `Card` component (`Shared/DesignSystem/Card/`)

One container, three optional slots + a tap behavior. Pure presentation; navigation is supplied
by the consumer through idiomatic SwiftUI wrappers.

### 3.1 Anatomy & API

```
Card(
    label:      String?              // uppercase category label (e.g. "RECOVERY")
    title:      String?              // primary title line
    accent:     Color? = nil         // domain tint; nil = neutral
    accessory:  CardAccessory = .none
    style:      CardStyle = .plain
    footer:     CardFooter? = nil
) { content }                        // @ViewBuilder — any content block (§4)
```

- `CardAccessory`: `.none` · `.chevron` · `.value(String)` · `.delta(value:String, direction:)` ·
  `.icon(systemName:)` · `.toggle(isOn: Binding<Bool>)` · `.learnMore`
- `CardStyle`: `.plain` (surface) · `.tinted(Color)` (subtle domain gradient) · `.media(content:)`
  (image/gradient hero behind header) — used sparingly to respect Apple-Health restraint
- `CardFooter`: `.text(String)` (insight line) · `.cta(title:String, action:)`

Visual spec: `surface` background, `Spacing.md` padding, 18-pt corner radius, `separator`
hairline in light mode, no hard shadow (Apple-Health flatness). Header row = label (caption,
`secondaryLabel`) + title + trailing accessory. Footer separated by `separator` hairline.

### 3.2 Tap behaviors

Card itself is presentation-only. Three thin, documented patterns/wrappers cover the required
"open a View or a Drawer":

- **Push a View:** `NavigationLink(value: route) { Card(...) { … } }` — Card renders as the link
  label; chevron accessory signals tappability.
- **Bottom Drawer:** `.cardDrawer(isPresented:detents:) { DrawerContent }` modifier — wraps
  `.sheet` with `presentationDetents([.medium, .large])` and a grabber. Convenience over raw
  `.sheet`.
- **Inline action / accordion:** `Card(... )` inside a `Button`, or an `ExpandableCard` wrapper
  that toggles a disclosed content region in place (Oura "Heart & stress" pattern).

A pressed-state highlight (subtle scale/opacity) applies whenever a tap behavior is attached.

### 3.3 Why this shape

Keeping `Card` dumb (no embedded navigation/data) means it's trivially previewable and unit/snapshot
friendly, and consumers stay in control of routing. Each content block (§4) is independently
testable and composes into the slot.

## 4. Content blocks & chart primitives (`Shared/DesignSystem/Blocks/`, `…/Charts/`)

Small, single-purpose views designed to sit in a Card's content slot. Each takes plain value
types (mock-friendly) and uses only palette tokens + `Spacing`/`Typography`.

**Blocks:** `ScoreRing` · `CompositeHeroRing` (center ring + satellite stats) · `HeroNumber` ·
`StatTile` · `ContributorRows` (label + progress + qualitative tag) · `ZoneScale` (colored zones
+ gradient legend) · `GoalProgress` (ring or bar) · `Sparkline` · `TagChips` · `MediaThumbnail` ·
`DeltaLabel` (▲▼ vs baseline) · `CoachPrompt` (AI entry) · `PeriodPicker` (Day/Week/Month/Year
segmented) · `DateScroller` (swipe between days).

**Charts (Swift Charts):** `LineTrendChart` (with dashed baseline + optional point annotations) ·
`BarSeriesChart` · `SleepStageChart` (§5) · `RingChart` (donut, reused by ScoreRing/MetricRings) ·
`WorkoutMapSnapshot` (MapKit static snapshot; falls back to a styled placeholder).

`MetricRings` is refactored to use `RingChart` + tokens (recovery/strain colors replaced by
domain tokens).

## 5. Sleep-stage chart (staggered horizontal columns)

Reference: the staggered horizontal column chart (Mobbin `43477a06-…`), plus Pillow/Ultrahuman
hypnograms. `SleepStageChart` renders the night as a **hypnogram**: time on the x-axis, four stage
rows stacked vertically (Awake top → REM → Light → Deep bottom). Each contiguous stage interval is
a **rounded horizontal column** drawn at its stage's row, so segments "stagger" across rows over
time. Colors are sleep-domain shades:

| Stage | Color |
|---|---|
| Awake | `strain` coral (alert/attention) |
| REM | `sleep` indigo (light shade) |
| Light | `recovery` blue |
| Deep | `sleep` indigo (dark shade) |

Implemented with Swift Charts `BarMark` (horizontal, `xStart`/`xEnd` = interval, `y` = stage),
`.cornerRadius`, one mark per interval. Below the chart: a **stage breakdown** using
`ContributorRows`-style bars showing each stage's **% and duration**. Data model:
`SleepStageInterval(stage: SleepStage, start: Date, end: Date)`; `SleepSession` aggregates
intervals + totals. Mock generator produces a realistic night.

## 6. Information architecture

Keep the existing **4 tabs**: Overview · Sleep · Recovery · Strain (the `HomeTab` enum is
unchanged). Overview becomes a **card feed (Today)**; each card deep-links into its domain tab or
a detail screen. Vitals are detail screens reached from cards. Profile stays behind the top-bar
avatar; a new **Settings** screen is reachable from Profile. A **`DateScroller`** sits at the top
of Overview. Navigation uses a per-tab `NavigationStack` with value-based routes
(`enum AppRoute`).

Shared screens live in `Shared/Screens/` so the macOS companion reuses them (it already mirrors
the iPhone screens); iOS-only pieces (sync drawer) stay under `iOS/`.

## 7. Screen catalog (FEATURES.md scope)

All built with mock data, all composed from `Card`. ~55 features.

**Overview (Today):** date scroller · recovery hero · sleep card · strain card · steps/activity
goal · heart-rate card · stress card · SpO₂ card · skin-temp card · respiratory card · ring-battery
card · coach insight · tags/journal entry.

**Sleep:** sleep-score hero · staggered-stage hypnogram · stage breakdown (Awake/REM/Light/Deep
%+duration) · contributors (efficiency, restfulness, latency, timing) · time in bed/asleep ·
sleeping HR · HRV during sleep · respiratory rate · bedtime/timing · sleep trends · sleep insight.

**Recovery:** recovery-score hero · contributors (HRV balance, RHR, body temp, recovery index,
sleep & activity balance) · HRV detail+trend · resting-HR detail+trend · body-temp deviation ·
respiratory rate · recovery trends · "What is Recovery?" educational.

**Strain:** day-strain hero · steps/distance/calories · activity goal · HR zones · workouts list ·
workout summary+map · active vs restorative time · move/inactivity · cardio load · VO₂max/cardio
fitness · strain trends.

**Vitals (detail screens):** heart rate · HRV · SpO₂ · stress monitor · skin temperature ·
respiratory rate.

**Cross-cutting:** trends (Day/Week/Month/Year) · tags & journal · mood check-in ·
insights/coaching feed · AI coach · profile (exists) · settings · Mac sync (exists) ·
device/battery status · onboarding.

`FEATURES.md` lives at repo root: a 4-column table — **Name · Description · Designed ·
Implemented**. *Designed* = specified here with a defined layout. *Implemented* = built as a
working SwiftUI screen with mock data, navigable in the app, building + linting green. The table
is updated as each screen lands.

## 8. Mock data

A `MockHealthData` provider (in `Shared/Model/`) supplies sample value types for every screen:
`DayMetrics` (extended), `SleepSession` + intervals, HRV/RHR/temp/respiratory series, HR-zone
buckets, step/calorie series, workouts, stress series, tags. Deterministic (seeded) so previews
and snapshot tests are stable. This replaces ad-hoc `.sample` literals.

## 9. Testing

- Keep all existing `OopsTests` green (protocol/manager/transport).
- Unit-test pure logic: sleep-stage aggregation (% + durations), delta/baseline math, score→band
  mapping, mock-data determinism.
- View code stays preview-driven; no snapshot harness is added (out of scope). Each screen ships
  with a `#Preview` in light + dark.
- SwiftLint (tokens + new color rule) must pass — it gates the build and CI.

## 10. Build phasing

1. **Foundation:** asset-catalog colors + `AppColor` tokens + SwiftLint color rule; migrate
   existing `.green`/`.blue`. Verify build + lint.
2. **Card + blocks + charts:** `Card`, accessories, drawer/expand wrappers, content blocks, chart
   primitives (incl. `SleepStageChart`), `MockHealthData`. Previews.
3. **Overview** card feed + date scroller + routing.
4. **Sleep** (hypnogram + breakdown + contributors + sub-screens).
5. **Recovery** + vitals detail screens.
6. **Strain** + workouts.
7. **Cross-cutting:** trends, tags/journal, mood, insights, settings, onboarding, device status.
8. `FEATURES.md` maintained throughout; `xcodegen generate` whenever files are added.

Each phase ends with a green iOS build + lint (and macOS build for shared screens).
