# Time Flow Logic

> Rules that govern how blocks behave when checked off early, late, or not at all.

---

## Overview

Every [Block](../concepts/blocks.md) in a formula has a **flow logic type** that determines what happens when the block's allocated time runs out or the user checks it off. This is the engine that keeps the schedule *alive* and adaptive.

---

## Flow Logic Types

### Type 1 — Flowing (Non-Blocking)

> The schedule keeps moving regardless of check-off.

| Event | Behaviour |
|---|---|
| Block time expires, **not checked** | Next block starts automatically. Unchecked block is marked as missed/partial |
| Block **checked early** | Remaining time is redistributed to upcoming priority blocks |

**Use case**: Low-stakes or time-boxed activities (e.g. "Breakfast — 5 min").

### Type 2 — Blocking

> The block stays active until manually checked off, postponing everything after it.

| Event | Behaviour |
|---|---|
| Block time expires, **not checked** | Block remains active. All subsequent blocks are postponed and **shrink** proportionally |
| Block **checked off** (any time) | Next block starts immediately |

**Use case**: Critical tasks that must be completed (e.g. "Deep Work session").

---

## Early Check-Off Rule

When any block (Type 1 or 2) is checked off **before** its duration ends:

1. The remaining time is **reclaimed**.
2. Reclaimed time is **distributed to priority blocks** — higher-priority blocks grow first.
3. The total day length stays constant (e.g. 16 h).

---

## Shrinking Rule (Type 2 Overrun)

When a Type 2 block overruns its duration:

1. All subsequent blocks are **shrunk proportionally** to fit the remaining day.
2. The algorithm respects [priority](../algorithms/scheduling.md) — low-priority blocks shrink first; high-priority blocks are protected.
3. If shrinking is insufficient, low-priority blocks may be **sacrificed** (removed entirely).

---

## Summary Table

| Scenario | Type 1 | Type 2 |
|---|---|---|
| Time expires, not checked | Next block starts; mark partial | Block persists; postpone rest |
| Checked early | Redistribute remaining time | Redistribute remaining time |
| Checked on time | Next block starts normally | Next block starts normally |
| Checked late | N/A (already moved on) | Release block; resume schedule |

---

## Open Questions

- ❓ Is shrinking linear or weighted by priority?
- ❓ Can the user override the auto-redistribution?
- ❓ What visual feedback shows shrinking in real time?

---

## Related Docs

- [Blocks](../concepts/blocks.md) — where flow logic is set
- [Scheduling Algorithm](scheduling.md) — priority-based rebalancing
- [Today Tab](../tabs/today.md) — where this logic runs live
