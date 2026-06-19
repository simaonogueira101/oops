# Oops — Features

Feature set for the app (modeled on Whoop + Oura, rendered stock-Apple).

**Legend**

- **Designed** — built as a SwiftUI screen/component with the design system.
- **Implemented** — **wired to real ring data** over Bluetooth. `BLERingTransport` (CoreBluetooth)
  is **written and working**: the app connects to a real Colmi R09, runs the QRing bind/init
  handshake, and syncs real sensor history + live HR. `MockHealthData` now only backs SwiftUI
  previews. All values shown in the app come from the ring or are "—" when that day has no data —
  no fabricated numbers.
- Design-system components and the iPhone↔Mac plumbing are **ring-independent**; for those rows
  _Implemented_ means "complete and functional".

**What the ring delivers today** (verified on-device): battery, heart-rate history (via a global
frame collector), HRV, SpO₂ (recovered via a late-V2-response cache), stress, skin temperature,
sleep stages, steps / distance / calories. Sparse where the ring wasn't worn. The "now" HR is the
latest HR-history sample. **Real-time live HR is effectively blocked on iOS** — the ring only
streams continuously on the fast connection interval an iOS central can't request, so it sends one
frame then goes silent (confirmed on-device). **Not available from the R09 / not yet derived:**
recovery score, strain score, respiratory rate, the contributor bands — these render "—".

## Design system (Implemented = component complete & functional)

| Name                                       | Description                                                                                                        | Designed | Implemented |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ | -------- | ----------- |
| Reduced color palette                      | 6-hue Oura-warm palette (recovery/sleep/strain + positive/caution/negative) + neutrals, light & dark, asset-backed | ✅       | ✅          |
| SwiftLint palette enforcement              | Bans SwiftUI system color literals so only `AppColor` tokens compile                                               | ✅       | ✅          |
| Card component                             | One container: header (label/title/accessory) + content slot + footer, tap → push/drawer/expand                    | ✅       | ✅          |
| Card drawer                                | Bottom-sheet presentation from a card (`.cardDrawer`)                                                              | ✅       | ✅          |
| Drawer navigation                          | Every tappable card opens a bottom drawer (no pushed views)                                                        | ✅       | ✅          |
| Expandable card                            | Accordion that discloses detail in place                                                                           | ✅       | ✅          |
| Score ring / composite hero ring           | Score donut + satellite stats                                                                                      | ✅       | ✅          |
| Goal progress (ring/bar)                   | Progress toward a target                                                                                           | ✅       | ✅          |
| Contributor rows                           | Label + progress + qualitative band                                                                                | ✅       | ✅          |
| Zone / range scale                         | Colored zones + gradient legend                                                                                    | ✅       | ✅          |
| Stat tile / hero number / delta label      | Compact value blocks + ▲▼ vs baseline                                                                              | ✅       | ✅          |
| Sparkline / line-trend / bar-series charts | Inline + full trend charts                                                                                         | ✅       | ✅          |
| Staggered sleep-stage hypnogram            | Awake→Deep staggered horizontal columns                                                                            | ✅       | ✅          |
| Period picker / date scroller              | Day/Week/Month/Year + day stepping                                                                                 | ✅       | ✅          |

## Overview (Today)

| Name                  | Description                                                            | Designed | Implemented                       |
| --------------------- | ---------------------------------------------------------------------- | -------- | --------------------------------- |
| Today card feed       | Scrollable feed; each card deep-links into its domain                  | ✅       | ✅                                |
| Recovery hero         | Composite ring (score + HRV/RHR/strain/sleep)                          | ✅       | 🟡 HRV/RHR real; score/strain "—" |
| Sleep summary card    | Score + sparkline → Sleep                                              | ✅       | ✅                                |
| Strain summary card   | Day strain + sparkline → Strain                                        | ✅       | 🟡 steps real; strain score "—"   |
| Steps goal card       | Progress toward step goal                                              | ✅       | ✅                                |
| Heart-rate card       | Resting/now + sparkline → Heart Rate                                   | ✅       | ✅                                |
| Day swipe paging      | Swipe left/right on the feed to change day (push transition + haptic)  | ✅       | ✅                                |
| Active workout banner | Thin live banner below the hero while recording; opens the live drawer | ✅       | ✅                                |

## Sleep

| Name                  | Description                                 | Designed | Implemented                       |
| --------------------- | ------------------------------------------- | -------- | --------------------------------- |
| Sleep score hero      | Score ring + time asleep + insight          | ✅       | ✅ (score from sleep performance) |
| Sleep-stage hypnogram | Staggered horizontal columns over the night | ✅       | ✅                                |
| Stage breakdown       | Awake/REM/Light/Deep %, + duration          | ✅       | ✅                                |
| Sleep contributors    | Efficiency, restfulness, latency, timing    | ✅       | 🟡 not derived → "—"              |
| Sleeping heart rate   | Overnight HR trend                          | ✅       | ✅ (resting HR + trend)           |
| Bedtime / timing      | Bedtime & wake                              | ✅       | ✅                                |
| Sleep trends          | Inline period selector + trend chart        | ✅       | ✅                                |

## Recovery

| Name                      | Description                                                           | Designed | Implemented                |
| ------------------------- | --------------------------------------------------------------------- | -------- | -------------------------- |
| Recovery score hero       | Score ring + band + insight                                           | ✅       | 🟡 score not derived → "—" |
| Recovery contributors     | HRV balance, RHR, body temp, recovery index, sleep & activity balance | ✅       | 🟡 not derived → "—"       |
| HRV detail + trend        | Sparkline card → HRV detail                                           | ✅       | ✅                         |
| Resting HR detail + trend | Sparkline card → Heart Rate detail                                    | ✅       | ✅                         |
| Body temperature          | Skin temp card (absolute °C) → detail                                 | ✅       | ✅                         |
| Blood oxygen (SpO₂)       | SpO₂ card + trend → detail                                            | ✅       | ✅                         |
| Stress                    | Stress card + trend → detail                                          | ✅       | ✅                         |
| Respiratory rate          | Card → detail                                                         | ✅       | 🟡 no R09 source → "—"     |
| Recovery trends           | Inline period selector + trend chart                                  | ✅       | ✅                         |

## Strain & Activity

| Name                        | Description                                                             | Designed | Implemented                              |
| --------------------------- | ----------------------------------------------------------------------- | -------- | ---------------------------------------- |
| Day strain hero             | Strain ring (0–21) + calories/steps                                     | ✅       | 🟡 calories/steps real; strain score "—" |
| Steps / distance / calories | Activity stat grid (all real from the ring's activity log)              | ✅       | ✅                                       |
| Heart-rate zones            | Zone scale → HR Zones                                                   | ✅       | ✅                                       |
| Workouts list + detail      | Live recorded history → detail (summary, HR trace)                      | ✅       | ✅                                       |
| Workout history persistence | Ending a recording saves a `WorkoutRecord` to the local SwiftData store | ✅       | ✅                                       |
| Record workout              | Separated "+" tab button → type picker drawer → start/end recording     | ✅       | ✅                                       |
| Live workout stats          | Elapsed time real; live HR/calories during a recording not yet wired    | ✅       | 🟡 elapsed real; HR/cal pending          |
| Cardio fitness (VO₂max)     | Estimated fitness (cut — not measurable by the R09)                     | ⬜       | ⬜                                       |
| Strain trends               | Inline period selector + trend chart                                    | ✅       | ✅                                       |
| HR zones screen             | Period picker + per-zone cards                                          | ✅       | ✅                                       |

## Vitals (detail screens)

One `MetricDetailScreen` template — trend + stats + explainer — per metric.

| Name                | Description                 | Designed | Implemented            |
| ------------------- | --------------------------- | -------- | ---------------------- |
| Heart rate          | Trend + stats               | ✅       | ✅                     |
| HRV                 | Trend + stats               | ✅       | ✅                     |
| Blood oxygen (SpO₂) | Trend + stats               | ✅       | ✅                     |
| Stress              | Trend + stats               | ✅       | ✅                     |
| Skin temperature    | Trend + stats (absolute °C) | ✅       | ✅                     |
| Respiratory rate    | Trend + stats               | ✅       | 🟡 no R09 source → "—" |

## App & infrastructure

| Name                   | Description                                                                      | Designed | Implemented |
| ---------------------- | -------------------------------------------------------------------------------- | -------- | ----------- |
| Profile                | Photo + name + appearance, stored locally                                        | ✅       | ✅          |
| Settings               | Goals, units, notifications, about (controls not yet persisted)                  | ✅       | ⬜          |
| Welcome / onboarding   | Tour screen (reachable from Settings; first-launch wiring is future)             | ✅       | ⬜          |
| iPhone → Mac sync      | Bonjour newline-JSON sync — battery **+ all sensor samples** (HR/HRV/SpO₂/stress/temp/activity/sleep), deduped on the Mac | ✅       | ✅          |
| Ring sync + force-sync | Full bind/init handshake + history pull; manual force-sync button in the top bar | ✅       | ✅          |
| Ring battery read      | Battery via `RingProtocol`/`RingManager` over BLE                                | ✅       | ✅          |
| BLE transport          | `BLERingTransport` — real CoreBluetooth link to the Colmi R09                    | ✅       | ✅          |
