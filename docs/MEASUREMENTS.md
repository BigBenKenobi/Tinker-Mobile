# Quiet-work measurements

Source: `db007a3390c8a2ff25e511f615d4e5ff0b8f713c`.
Native samples come from MaintenanceTests in
[run 37647511855](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37647511855).
They are correctness/per-workload observations on Simulator, with no physical
battery, UI frame-time or latency acceptance implied. Timings have no pass/fail
threshold and should not be treated as stable benchmarks across runners.

## iPhone SE 3, Xcode 16.4 / iOS 18.5

| Workload | Records | Measured time | Observable result |
|---|---:|---:|---|
| 100 empty pull pages | 1,000 | 4.406 ms total | Zero record publications; cursor and records unchanged |
| 100 empty pull pages | 10,000 | 2.147 ms total | Zero record publications; cursor and records unchanged |
| Cold calendar projection | 1,000 | 12.717 ms | Existing recurrence semantics retained |
| 100 cached projections | 1,000 | 0.272 ms total | Same occurrence IDs; visibility/generation invalidation tested |
| Cold calendar projection | 10,000 | 8.252 ms | Existing recurrence semantics retained |
| 100 cached projections | 10,000 | 0.257 ms total | Same occurrence IDs; visibility/generation invalidation tested |

The calendar dataset contains one monthly event beginning in 2020 and otherwise
notes, viewed in October 2026. These numbers measure projection-cache calls, not
all CalendarView filtering/rendering and not thousands of historical series.
There is no pre-change device benchmark. The lower 10,000-record timings reflect
measurement noise/warm-up; they do not show improved scaling with more records.

Notification diff tests show no replacements for identical OS requests and exactly
one replacement for changed content. Planning rechecks relevant generation changes
and renews at least once per minute; actual delivery still requires phone testing.

Routine CI ran 45 unit regressions and two UI smoke cases on this candidate. The
small-phone UI smoke took 122.532 seconds. The full four-case interface suite at
`3be794b` took 439.231 seconds on the same phone size in run 37645017150; those are
different runner sessions and suite scopes. Full capture remains available for
UI changes and manual acceptance requests.

## iPhone 16 Pro Max, same toolchain/runtime

| Workload | Records | Measured time |
|---|---:|---:|
| 100 empty pull pages, zero publications | 1,000 | 1.438 ms total |
| 100 empty pull pages, zero publications | 10,000 | 2.163 ms total |
| Cold calendar projection | 1,000 | 7.194 ms |
| 100 cached projections | 1,000 | 0.291 ms total |
| Cold calendar projection | 10,000 | 9.015 ms |
| 100 cached projections | 10,000 | 0.263 ms total |

Both phones passed 47 tests with zero failures, skips or expected failures.
Raw timing log samples are retained in [measurements JSON](validation/measurements-db007a3.json).

## Next measurements after physical acceptance

Profile many historical recurring series, tombstones, exception-heavy calendars,
60 scheduled reminders, reconnect and prolonged foreground use on the actual
phone. Record dataset shape, device/iOS/build identity and repeated samples.
Consider recurrence fast-forwarding or moving storage off MainActor only after
those profiles identify material work; preserve COUNT, DST and month-end behavior.
