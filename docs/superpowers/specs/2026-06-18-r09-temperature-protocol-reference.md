# R09 body-temperature BLE protocol (reference, future slice)

**Status:** Researched, NOT yet implemented. Out of scope for the real-data-sync slice; this is
the reference for a later "body temperature" slice. Confidence: HIGH (Gadgetbridge source,
cross-confirmed). Must be byte-verified against our own R09 capture before shipping.

## Key surprise: temperature does NOT use our existing protocol

It does **not** ride `RingProtocol` (the 16-byte, `byte[0]`=opcode, `byte[15]`=checksum packets
on the `6E40FFF0…` service). It uses a **second GATT service** — "Big Data V2" — with
variable-length, **un-checksummed** framing. Our transport assumes one service + fixed 16-byte
packets, so this needs a **second characteristic pair** and a separate framing path.

| Purpose | UUID |
|---|---|
| V1 service (battery/HR/steps — our existing path) | `6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E` |
| **V2 Big-Data service** | `de5bf728-d711-4e47-af26-65e3012a5dc7` |
| **V2 write (request)** | `de5bf72a-d711-4e47-af26-65e3012a5dc7` |
| **V2 notify (response)** | `de5bf729-d711-4e47-af26-65e3012a5dc7` |

## Candidate 1 — Big-Data V2 historical temperature (HIGH confidence)

Confirmed from Gadgetbridge `devices/yawell/ring/` (Colmi rings are Yawell-branded).

**Prerequisite (on the V1 16-byte channel):** enable all-day temperature monitoring first, or
the ring returns no history (the "stuck fetching" bug, GB issues #4451/#4491):
- Enable: `{0x3A, 0x03, 0x02, 0x01}` (pad to 16 + checksum, via `makePacket`)
- Read setting: `{0x3A, 0x03, 0x01}`

**Request** (written raw to `de5bf72a…`, NOT padded, NO checksum):
```
BC 25 01 00 3E 81 02
```
- `0xBC` = CMD_BIG_DATA_V2, `0x25` = BIG_DATA_TYPE_TEMPERATURE
- `01 00` = LE payload length (1); `3E 81 02` = fixed request/CRC trailer from QRing capture

**Response** (notify on `de5bf729…`): `byte[0]=0xBC`, `byte[1]=0x25`, `byte[2..3]`=uint16 LE
payload length, data from **index 6** as per-day blocks: `[days_ago][0x1E skip]` then **48 bytes
= 24h × 2 half-hourly samples**.

**Scaling (load-bearing — read UNSIGNED):**
```
raw = byte & 0xFF            // signed read is a known bug (#4451): temps ≥32.8°C go negative
tempC = (raw / 10.0) + 20.0  // raw == 0 means "no reading"; range ~20.0–45.5°C
```

## Candidate 2 — real-time temperature via 0x69 (MEDIUM, fallback)

From `dm94/colmi-ha`. Reuses the V1 real-time channel:
- Cmd `0x69`, reading_type `0x0B` (temp), sub `0x01` start / `0x04` stop (16-byte + checksum)
- Response `data[0]=0x69, data[1]=0x0B, data[2]=err`, temp in `data[3]`: `tempC = data[3]/10 + 20`,
  valid only when `data[3] >= 11`. Firmware-dependent; use as a *live* read if V2 is absent.

## Bring-up order on the physical ring

1. Enable `0x3A` on V1, wait, then write `BC 25 01 00 3E 81 02` to `de5bf72a…`; parse V2 notify
   with `(raw & 0xFF)/10 + 20`. (Highest confidence.)
2. If the R09 lacks the V2 service, try `0x69`+`0x0B` real-time on V1.
3. Else capture our own (below).

## Self-capture plan (if neither matches)

1. Pair R09 with official **QRing** on Android, sync temperature once.
2. Developer options → enable **Bluetooth HCI snoop log**; toggle BT.
3. Trigger a temperature sync in QRing.
4. Pull `btsnoop_hci.log` (rooted `adb pull /data/misc/bluetooth/logs/…`, else `adb bugreport`).
5. Wireshark: map UUIDs `de5bf72a/729…` to handles; request `btatt.opcode==0x52 && value[0:2]==bc:25`,
   notify `btatt.opcode==0x1b && value[0:2]==bc:25`.

## Sources
- Gadgetbridge (canonical): https://codeberg.org/Freeyourgadget/Gadgetbridge — `…/yawell/ring/`
- GB #4451 (temp fix: request bytes + unsigned scaling): https://codeberg.org/Freeyourgadget/Gadgetbridge/issues/4451
- GB #4491 (R09 no temperature data): https://codeberg.org/Freeyourgadget/Gadgetbridge/issues/4491
- GB PR #3896 (Colmi R0x support): https://codeberg.org/Freeyourgadget/Gadgetbridge/pulls/3896
- dm94/colmi-ha (real-time temp candidate): https://github.com/dm94/colmi-ha
