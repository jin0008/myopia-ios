# Screen Time / Near-work activity plan (v2)

Apple does not expose raw Screen Time data to third-party apps. Parents who want this capability must:

1. Use Apple **Family Sharing** (child's iPhone is set up as a member of the parent's Family).
2. The parent's app uses Apple's **Family Controls** framework + **DeviceActivity** framework to observe the child's device activity and report aggregated usage back to the parent's device.

Both require the **Family Controls entitlement**, which you must request from Apple at <https://developer.apple.com/contact/request/family-controls-distribution>. Approval can take days to weeks; plan accordingly.

## Approach

```
┌────────────────────┐                 ┌────────────────────┐
│ Child iPhone       │                 │ Parent iPhone      │
│ ─────────────      │                 │ ─────────────      │
│ EAGLE vision│  Family Sharing │ EAGLE vision│
│ + DeviceActivity   │ ◄─────────────► │ (reads aggregated  │
│   extension        │                 │  Near-work minutes)│
│                    │                 │                    │
│ Classifies apps    │                 │ Shows near-work    │
│ as "near-work"     │                 │ series alongside   │
│ (reading, YouTube, │                 │ axial length graph │
│  gaming, etc.)     │                 │                    │
└─────────┬──────────┘                 └─────────┬──────────┘
          │                                      │
          └──────────► /api/mobile/.../nearwork-samples ◄──┘
```

## App-side components

1. **FamilyActivityPicker** – parent categorises the child's apps as `nearWork | outdoor | neutral`.
2. **DeviceActivityMonitor extension** – a small system extension that counts minutes per category each day.
3. **Shared App Group** – the extension and the main app share a container to persist the daily counters.
4. **Background upload task** – once per day, main app uploads the previous day's aggregated minutes to `POST /api/mobile/children/:childId/nearwork-samples`.

## Classification defaults

Default "near-work" bucket (user editable):
- Books, Kindle, Apple Books
- Web browsers
- YouTube, Netflix on phone screen
- Most games
- Social media with scrolling feeds

## Privacy notes

- Family Controls data **never leaves the parent's device unless the parent opts in** to the per-child cloud upload toggle. Default: off.
- The app must surface the Screen Time usage disclosure and the **Family Controls authorization prompt** before enabling.

## v2 roadmap deliverables

- [ ] Apply for Family Controls entitlement
- [ ] Add `FamilyControls` and `DeviceActivity` frameworks to the app
- [ ] Build the FamilyActivityPicker UI for bucket editing
- [ ] Implement DeviceActivityMonitor extension target
- [ ] Implement App Group storage + background upload
- [ ] Backend: `nearwork_sample` table, `POST /nearwork-samples`, chart overlay on web + app
- [ ] Privacy review + App Store submission with Family Controls justification
