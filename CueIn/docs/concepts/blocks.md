# Blocks

> A block is a single time slot in a formula — it can be a task, a placeholder, or a container for a mini-formula.

---

## Overview

Blocks are the **atoms** of a schedule. Every [Formula](formulas.md) is an ordered list of blocks. A block always has a name and a duration, but its nature varies — it can be a concrete action ("Morning Run"), a placeholder for external work ("Work"), or a group containing sub-blocks via a [Mini-Formula](formulas.md#formulas-vs-mini-formulas).

---

## Properties

| Property | Type | Required | Description |
|---|---|---|---|
| Name | `String` | ✅ | Display label |
| Duration | `TimeInterval` | ✅ | How long the block lasts |
| Category | `Category` | ✅ | Top-level classification (see below) |
| Subcategory | `String` | ❌ | Specific label within the category |
| Priority | `Int` | ❌ | Importance level — used by [Scheduling](../algorithms/scheduling.md) during roadblocks |
| Flow Logic | `Type1` / `Type2` | ✅ | Check-off behaviour — see [Time Flow](../algorithms/time-flow.md) |
| Color | `Color` | ❌ | Visual color in the schedule |
| Details | `String` | ❌ | Free-text info accessible via tap/expand |
| Checkbox | `Bool` | ✅ | Whether the block has a check-off control |
| Mini-Formula | `Formula?` | ❌ | If set, the block expands into sub-blocks |

---

## Block UI

```
┌──────────────────────────────────────────────┐
│  ☐  Morning Run      ◷ 12:34   ⋯           │
│     checkbox  name    remaining  menu        │
└──────────────────────────────────────────────┘
```

- **Checkbox** (left) — check off when done.
- **Name** — block label.
- **Timer** — circular icon + countdown of remaining duration.
- **⋯ Menu** — delete, rename, rearrange, change flow logic.

---

## Categories

Categories are **pre-made top-level labels**. Users add their own **subcategories** within them.

| Category | Example Subcategories |
|---|---|
| **Work** | Deep Work, Shallow Work, Creative Work, Meetings |
| **Sport** | Cardio, Boxing, Stretching, Resistance Training |
| **Study** | Computer Science, Math, Physics, Languages |
| **Wellness** | Meditation, Cold Shower, Journaling |
| *Custom* | Users can create additional categories ❓ |

> ⚠️ Categories are critical for the [Stats](../features/stats.md) system — average durations and breakdowns are computed per category/subcategory.

---

## Block Types by Usage

| Usage | Example | Behaviour |
|---|---|---|
| **Direct Task** | "Morning Run" | A concrete action the user performs |
| **Placeholder** | "Work", "Studying" | Reserves time; actual tasks happen outside CueIn |
| **Group / Mini-Formula** | "Morning Routine" | Expands into sub-blocks (Run, Shower, Meditate) |
| **Small Repeatable** | "Drink Water" | Recurring reminder; doesn't override other blocks |

---

## Modification Scope

When changing a block's duration, order, or properties:

| Scope | Effect |
|---|---|
| **Today only** | Change applies to the current day's instance |
| **This formula** | Permanently modifies the formula definition |

---

## Open Questions

- ❓ Can users create custom categories (beyond the pre-made set)?
- ❓ Is there a max nesting depth (blocks inside mini-formulas inside formulas)?
- ❓ Can a block belong to multiple categories?

---

## Related Docs

- [Formulas](formulas.md) — blocks live inside formulas
- [Time Flow Logic](../algorithms/time-flow.md) — how check-off timing works
- [Scheduling](../algorithms/scheduling.md) — how priority affects rearrangement
- [Stats](../features/stats.md) — categories drive analytics
