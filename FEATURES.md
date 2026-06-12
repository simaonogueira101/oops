# Oops — Features

Feature set for the app (modeled on Whoop + Oura, rendered stock-Apple).

**Legend**
- **Designed** — built as a SwiftUI screen/component with the design system, running on
  **mock data** (`MockHealthData`).
- **Implemented** — **fully wired to real ring data** over Bluetooth. The BLE transport
  (`BLERingTransport`) **isn't written yet** and everything runs on `MockRingTransport`, so every
  metric-bearing screen is ⬜ today — it renders realistic placeholders, not your ring.
- Design-system components and the iPhone↔Mac plumbing are **ring-independent**; for those rows
  *Implemented* means "complete and functional".

## Design system (Implemented = component complete & functional)

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Reduced color palette | 6-hue Oura-warm palette (recovery/sleep/strain + positive/caution/negative) + neutrals, light & dark, asset-backed | ✅ | ✅ |
| SwiftLint palette enforcement | Bans SwiftUI system color literals so only `AppColor` tokens compile | ✅ | ✅ |
| Card component | One container: header (label/title/accessory) + content slot + footer, tap → push/drawer/expand | ✅ | ✅ |
| Card drawer | Bottom-sheet presentation from a card (`.cardDrawer`) | ✅ | ✅ |
| Expandable card | Accordion that discloses detail in place | ✅ | ✅ |
| Score ring / composite hero ring | Score donut + satellite stats | ✅ | ✅ |
| Goal progress (ring/bar) | Progress toward a target | ✅ | ✅ |
| Contributor rows | Label + progress + qualitative band | ✅ | ✅ |
| Zone / range scale | Colored zones + gradient legend | ✅ | ✅ |
| Stat tile / hero number / delta label | Compact value blocks + ▲▼ vs baseline | ✅ | ✅ |
| Sparkline / line-trend / bar-series charts | Inline + full trend charts | ✅ | ✅ |
| Staggered sleep-stage hypnogram | Awake→Deep staggered horizontal columns | ✅ | ✅ |
| Period picker / date scroller | Day/Week/Month/Year + day stepping | ✅ | ✅ |
| Workout map snapshot | Non-interactive route map (placeholder; no GPS yet) | ✅ | ⬜ |

## Overview (Today)

Implemented ⬜ across the board — these render mock data until the ring is connected.

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Today card feed | Scrollable feed; each card deep-links into its domain | ✅ | ⬜ |
| Recovery hero | Composite ring (score + HRV/RHR/strain/sleep) | ✅ | ⬜ |
| Sleep summary card | Score + sparkline → Sleep | ✅ | ⬜ |
| Strain summary card | Day strain + sparkline → Strain | ✅ | ⬜ |
| Steps goal card | Progress toward step goal | ✅ | ⬜ |
| Heart-rate card | Resting/now + sparkline → Heart Rate | ✅ | ⬜ |
| Stress card | Daytime stress → Stress | ✅ | ⬜ |
| Blood oxygen card | SpO₂ → Blood Oxygen | ✅ | ⬜ |
| Skin temperature card | Nightly deviation → Skin Temp | ✅ | ⬜ |
| Respiratory rate card | Breaths/min → Respiratory | ✅ | ⬜ |

## Sleep

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Sleep score hero | Score ring + time asleep + insight | ✅ | ⬜ |
| Sleep-stage hypnogram | Staggered horizontal columns over the night | ✅ | ⬜ |
| Stage breakdown | Awake/REM/Light/Deep %, + duration | ✅ | ⬜ |
| Sleep contributors | Efficiency, restfulness, latency, timing | ✅ | ⬜ |
| Time in bed / asleep | Aggregate durations | ✅ | ⬜ |
| Sleeping heart rate | Overnight HR trend | ✅ | ⬜ |
| HRV during sleep | Overnight HRV trend | ✅ | ⬜ |
| Respiratory rate (sleep) | Overnight respiratory sparkline | ✅ | ⬜ |
| Bedtime / timing | Bedtime & wake | ✅ | ⬜ |
| Sleep trends | Inline period selector + trend chart | ✅ | ⬜ |

## Recovery

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Recovery score hero | Score ring + band + insight | ✅ | ⬜ |
| Recovery contributors | HRV balance, RHR, body temp, recovery index, sleep & activity balance | ✅ | ⬜ |
| HRV detail + trend | Sparkline card → HRV detail | ✅ | ⬜ |
| Resting HR detail + trend | Sparkline card → Heart Rate detail | ✅ | ⬜ |
| Body temperature | Deviation card → detail | ✅ | ⬜ |
| Respiratory rate | Card → detail | ✅ | ⬜ |
| Recovery trends | Inline period selector + trend chart | ✅ | ⬜ |

## Strain & Activity

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Day strain hero | Strain ring (0–21) + calories/steps | ✅ | ⬜ |
| Steps / distance / calories | Activity stat grid | ✅ | ⬜ |
| Move goal | Goal ring | ✅ | ⬜ |
| Heart-rate zones | Zone scale → HR Zones | ✅ | ⬜ |
| Workouts list + detail | List → detail (map, summary, HR trace) | ✅ | ⬜ |
| Active vs restorative | Time split | ✅ | ⬜ |
| Cardio load | Daily bar series | ✅ | ⬜ |
| Cardio fitness (VO₂max) | Estimated fitness | ✅ | ⬜ |
| Strain trends | Inline period selector + trend chart | ✅ | ⬜ |
| HR zones screen | Period picker + per-zone cards | ✅ | ⬜ |

## Vitals (detail screens)

One `MetricDetailScreen` template — trend + stats + explainer — per metric.

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Heart rate | Trend + stats | ✅ | ⬜ |
| HRV | Trend + stats | ✅ | ⬜ |
| Blood oxygen (SpO₂) | Trend + stats | ✅ | ⬜ |
| Stress | Trend + stats | ✅ | ⬜ |
| Skin temperature | Trend + stats | ✅ | ⬜ |
| Respiratory rate | Trend + stats | ✅ | ⬜ |

## App & infrastructure

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Profile | Photo + name + appearance, stored locally | ✅ | ✅ |
| Settings | Goals, units, notifications, about (controls not yet persisted) | ✅ | ⬜ |
| Welcome / onboarding | Tour screen (reachable from Settings; first-launch wiring is future) | ✅ | ⬜ |
| iPhone → Mac sync | Bonjour newline-JSON sync (existing, real) | ✅ | ✅ |
| Ring battery read | Battery via `RingProtocol`/`RingManager` (on `MockRingTransport`; BLE not written) | ✅ | ⬜ |
| BLE transport | `BLERingTransport` — the real Bluetooth link that makes everything above ⬜ → ✅ | ⬜ | ⬜ |
