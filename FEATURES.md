# Oops — Features

Tracking for the app's feature set (modeled on Whoop + Oura, rendered stock-Apple). Every
screen is built today against **mock data** (`MockHealthData`); it binds to real ring data later
with no structural change.

**Legend** — **Designed**: specified in `docs/superpowers/specs/2026-06-11-oops-app-screens-and-card-system-design.md` with a defined layout. **Implemented**: built as a navigable SwiftUI screen (or reusable component) with mock data, building + linting green.

## Design system

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
| Sparkline / line-trend / bar-series charts | Inline + full trend charts (dashed baseline, last point) | ✅ | ✅ |
| Staggered sleep-stage hypnogram | Awake→Deep staggered horizontal columns | ✅ | ✅ |
| Tag chips / flow layout | Selectable wrapping chips | ✅ | ✅ |
| Media thumbnail / coach prompt | Educational row + AI-coach entry pill | ✅ | ✅ |
| Period picker / date scroller | Day/Week/Month/Year + day stepping | ✅ | ✅ |
| Workout map snapshot | Non-interactive route map placeholder | ✅ | ✅ |

## Overview (Today)

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Today card feed | Scrollable feed; each card deep-links into its domain | ✅ | ✅ |
| Recovery hero | Composite ring (score + HRV/RHR/strain/sleep) | ✅ | ✅ |
| Sleep summary card | Score + sparkline → Sleep | ✅ | ✅ |
| Strain summary card | Day strain + sparkline → Strain | ✅ | ✅ |
| Steps goal card | Progress toward step goal | ✅ | ✅ |
| Heart-rate card | Resting/now + sparkline → Heart Rate | ✅ | ✅ |
| Stress card | Daytime stress → Stress | ✅ | ✅ |
| Blood oxygen card | SpO₂ → Blood Oxygen | ✅ | ✅ |
| Skin temperature card | Nightly deviation → Skin Temp | ✅ | ✅ |
| Respiratory rate card | Breaths/min → Respiratory | ✅ | ✅ |
| Ring battery card | Battery/connection → Device status | ✅ | ✅ |
| Coach insight card | Daily insight line | ✅ | ✅ |
| Tags/journal entry card | Prompt → Journal | ✅ | ✅ |

## Sleep

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Sleep score hero | Score ring + time asleep + insight | ✅ | ✅ |
| Sleep-stage hypnogram | Staggered horizontal columns over the night | ✅ | ✅ |
| Stage breakdown | Awake/REM/Light/Deep %, + duration | ✅ | ✅ |
| Sleep contributors | Efficiency, restfulness, latency, timing | ✅ | ✅ |
| Time in bed / asleep | Aggregate durations | ✅ | ✅ |
| Sleeping heart rate | Overnight HR trend | ✅ | ✅ |
| HRV during sleep | Overnight HRV trend | ✅ | ✅ |
| Respiratory rate (sleep) | Overnight respiratory sparkline | ✅ | ✅ |
| Bedtime / timing | Bedtime & wake | ✅ | ✅ |
| Sleep trends | Link into Trends | ✅ | ✅ |

## Recovery

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Recovery score hero | Score ring + band + insight | ✅ | ✅ |
| Recovery contributors | HRV balance, RHR, body temp, recovery index, sleep & activity balance | ✅ | ✅ |
| HRV detail + trend | Sparkline card → HRV detail | ✅ | ✅ |
| Resting HR detail + trend | Sparkline card → Heart Rate detail | ✅ | ✅ |
| Body temperature | Deviation card → detail | ✅ | ✅ |
| Respiratory rate | Card → detail | ✅ | ✅ |
| Recovery trends | Link into Trends | ✅ | ✅ |
| "What is Recovery?" | Educational media card | ✅ | ✅ |

## Strain & Activity

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Day strain hero | Strain ring (0–21) + calories/steps | ✅ | ✅ |
| Steps / distance / calories | Activity stat grid | ✅ | ✅ |
| Move goal | Goal ring | ✅ | ✅ |
| Heart-rate zones | Zone scale → HR Zones | ✅ | ✅ |
| Workouts list | Workouts → list → detail | ✅ | ✅ |
| Workout detail | Map + summary + HR trace | ✅ | ✅ |
| Active vs restorative | Time split | ✅ | ✅ |
| Cardio load | Daily bar series | ✅ | ✅ |
| Cardio fitness (VO₂max) | Estimated fitness | ✅ | ✅ |
| Strain trends | Link into Trends | ✅ | ✅ |
| HR zones screen | Period picker + per-zone cards | ✅ | ✅ |

## Vitals (detail screens)

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Heart rate | Trend + stats + about | ✅ | ✅ |
| HRV | Trend + stats + about | ✅ | ✅ |
| Blood oxygen (SpO₂) | Trend + stats + about | ✅ | ✅ |
| Stress | Trend + stats + about | ✅ | ✅ |
| Skin temperature | Trend + stats + about | ✅ | ✅ |
| Respiratory rate | Trend + stats + about | ✅ | ✅ |

## Cross-cutting

| Name | Description | Designed | Implemented |
|---|---|---|---|
| Trends | Period picker + cross-domain trend cards | ✅ | ✅ |
| Tags & journal | Tag chips + note | ✅ | ✅ |
| Mood check-in | 5-level mood selector | ✅ | ✅ |
| Insights / coaching | Daily insight card on Overview | ✅ | ✅ |
| AI coach | Coach prompt block exists; conversational screen not yet wired | ✅ | ⬜ |
| Profile | Photo + name + appearance (existing) | ✅ | ✅ |
| Settings | Goals, units, notifications, ring, about | ✅ | ✅ |
| Device / battery status | Ring battery + device info | ✅ | ✅ |
| Welcome / onboarding | Tour screen (reachable from Settings; first-launch wiring is future) | ✅ | ✅ |
| iPhone → Mac sync | Bonjour sync (existing) | ✅ | ✅ |
| Ring battery (real transport) | Mock transport battery read (existing) | ✅ | ✅ |
