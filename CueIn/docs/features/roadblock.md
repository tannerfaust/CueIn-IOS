# Roadblock

> An interruption-handling flow triggered when something unplanned disrupts the schedule.

---

## Overview

When the user's day doesn't go as planned, they press the **Roadblock** button (which replaces the Start button after the day begins). This opens a menu of recovery options that gracefully modify the running schedule.

---

## Trigger

- **Button**: "Roadblock" (top-right of the [Today Tab](../tabs/today.md)).
- **Available**: only after the schedule has been started.

---

## Options

| Option | What it does |
|---|---|
| **Tune into the Flow** | Launches a 15-minute [Mini-Formula](../concepts/formulas.md) (e.g. Meditate, Breathe). Overrides the current block |
| **Add a Task** | Inserts a one-off task into the schedule |
| **Add Small Repeatable** | Adds a lightweight recurring reminder that runs alongside blocks |

---

## "Tune into the Flow" Details

1. A predefined or user-selected mini-formula starts immediately.
2. The **current block** is overridden (paused or replaced).
3. After the mini-formula completes, the schedule resumes.
4. Duration: typically 15 minutes (configurable ❓).

---

## Add-a-Task Details

Full flow documented in [Today Tab → Add-a-Task](../tabs/today.md#add-a-task-flow).

Quick summary:
1. Name → 2. Duration (specified / unspecified) → 3. Time (pinned / auto-placed) → 4. Flow Logic → 5. Scope (today / formula / all formulas).

---

## Schedule Impact

When a roadblock inserts new time, the app must **rebalance** the remaining schedule. This uses [Priority-based scheduling](../algorithms/scheduling.md) to decide which blocks shrink or get sacrificed.

---

## Related Docs

- [Today Tab](../tabs/today.md) — where roadblock lives
- [Time Flow Logic](../algorithms/time-flow.md) — how blocks adjust
- [Scheduling](../algorithms/scheduling.md) — priority-based rebalancing
