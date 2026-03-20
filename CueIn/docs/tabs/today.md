# Today Tab

> The daily command center — shows today's active formula as a live schedule you follow in real time.

---

## Overview

The Today tab is what the user sees most. It displays the **currently active formula** as a scrollable list of time blocks. A progression bar tracks elapsed time, and blocks are checked off as the day progresses. The schedule starts on-demand (not clock-based) when the user presses **Start**.

---

## UI Layout (top → bottom)

| Element | Description |
|---|---|
| **Stage Banner** | Thin info strip showing the user's current life stage (pulled from Profile) |
| **Progression Bar** | Horizontal loading bar spanning 16 h (editable). Starts filling on **Start** press |
| **Start / Roadblock Button** | Top-right. Before start → `Start`. After start → `Roadblock` |
| **View Toggle** | `Focused` / `Regular` — controls how blocks are displayed |
| **Schedule Window** | The main content area — a vertical list of blocks |
| **⋯ Menu** | Top-right three-dot menu with options (e.g. *Change Formula*) |

---

## View Modes

| Mode | Behaviour |
|---|---|
| **Focused** | Only the current block is centered and fully visible; surrounding blocks are blurred and shrunk. Multiple blocks shown only if concurrent |
| **Regular** | Standard scrollable list. Tap a block to expand details |

---

## Start Flow

1. User opens Today tab → sees the day's formula (not yet active).
2. Presses **Start** → progression bar begins filling, first block activates.
3. **Start** button transforms into **Roadblock** button.

> ⚠️ The schedule is **Start-based**, not clock-based. "Hour 0" = the moment Start is pressed (typically wake-up).

---

## Roadblock Flow

Triggered when something unplanned happens. Options:

| Option | Effect |
|---|---|
| **Tune into the Flow** | Launches a 15-minute mini-formula (e.g. Meditate). Overrides the current block |
| **Add a Task** | Inserts an ad-hoc task into the schedule (see flow below) |
| **Add Small Repeatable** | Adds a lightweight recurring reminder (e.g. "Drink water every 1 h") that does **not** override other blocks |

### Add-a-Task Flow

1. **Name** — enter the task name.
2. **Duration** — `Specified` (enter minutes/hours) or `Unspecified` (runs until manually checked off, blocking subsequent blocks).
3. **Time** — optionally pin to a clock time (e.g. 12:00). If left empty, the app auto-places it at the best fit.
4. **Flow Logic** — choose check-off behaviour (see [Time Flow Logic](../algorithms/time-flow.md)).
5. **Scope** — apply the task:
   - *Today only*
   - *This formula* (permanent change)
   - *All formulas* (added to every formula in the week schedule)

### Small Repeatable

- Does **not** override other blocks.
- Checkbox optional (default: no checkbox).
- Has an interval (e.g. every 1 h).
- Example: "Drink water".

---

## ⋯ Menu Options

- **Change Formula** — opens the formula library to pick or create a new formula for today.
- ❓ *Other menu items TBD.*

---

## Open Questions

- ❓ What is the best name for this tab? ("Today" vs alternatives)
- ❓ What other options live in the ⋯ menu?
- ❓ Can the user pause the progression bar?

---

## Related Docs

- [Blocks](../concepts/blocks.md) — what the schedule is made of
- [Formulas](../concepts/formulas.md) — what defines the schedule
- [Time Flow Logic](../algorithms/time-flow.md) — how check-off and shrinking work
- [Roadblock](../features/roadblock.md) — full roadblock feature spec
