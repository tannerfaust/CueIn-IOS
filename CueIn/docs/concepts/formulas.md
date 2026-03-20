# Formulas

> A formula is a predefined, customizable schedule for an entire day — the core building block of CueIn.

---

## Overview

A formula defines **what a day looks like**. It is an ordered list of [Blocks](blocks.md) with durations, arranged to fill a target day length (default: 16 hours). Users design formulas in the [Lab](../tabs/lab.md), assign them to days via a [Week Schedule](week-schedule.md), and execute them in the [Today](../tabs/today.md) tab.

---

## Types

| Type | Description | Example |
|---|---|---|
| **Full Formula** | Covers an entire day (target hours) | "Productive Weekday", "Recovery Sunday" |
| **Mini-Formula** | A small sub-schedule that lives *inside* a block | "Morning Routine" (contains: Run, Shower, Meditate) |

---

## Properties

| Property | Type | Description |
|---|---|---|
| Name | `String` | User-defined label |
| Target Duration | `Int` (hours) | Total hours the formula spans (default `16`) |
| Blocks | `[Block]` | Ordered list of blocks |
| Type | `full` / `mini` | Whether it's a day formula or a sub-schedule |
| Status | `active` / `inactive` | Whether it's currently assigned to any day |

---

## Formulas vs. Mini-Formulas

```
Week Schedule
  └─ Monday → "Productive Weekday" (full formula)
       ├─ Block: "Morning Routine" ← this IS a mini-formula
       │    ├─ Morning Run (15 min)
       │    ├─ Cold Shower (5 min)
       │    └─ Meditation (10 min)
       ├─ Block: Studying (2 h)
       ├─ Block: Work (4 h)
       └─ Block: Evening Training (1 h)
```

- A **mini-formula** can be embedded in a full formula at design time.
- A mini-formula can also be **triggered on-the-fly** via the Roadblock → "Tune into the Flow" action.

---

## Modification Scope

Whenever a user changes a formula (add/remove blocks, change durations, reorder), they choose:

| Scope | Effect |
|---|---|
| **Today only** | Temporary change, reverts tomorrow |
| **This formula** | Permanent change to the formula definition |
| **All formulas** | Change applied to every formula in the week schedule |

---

## Related Docs

- [Blocks](blocks.md) — the units that make up a formula
- [Week Schedule](week-schedule.md) — assigning formulas to days
- [Formula Editor](../features/formula-editor.md) — UI for creating/editing
- [Today Tab](../tabs/today.md) — where formulas are executed
