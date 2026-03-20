# Week Schedule

> A 7-day layout that assigns one or more formulas to each day of the week.

---

## Overview

The week schedule is the bridge between [Formulas](formulas.md) and the [Today Tab](../tabs/today.md). It maps each day (Sunday → Saturday) to one or more formulas. Users can maintain multiple **week presets** and switch between them.

---

## Structure

```
Week Schedule (preset: "Standard Work Week")
  ├─ Sunday    → "Recovery Day"
  ├─ Monday    → "Productive Weekday"
  ├─ Tuesday   → "Productive Weekday"
  ├─ Wednesday → "Productive Weekday"
  ├─ Thursday  → "Deep Work Day"
  ├─ Friday    → "Productive Weekday"
  └─ Saturday  → "Creative Saturday"
```

---

## Properties

| Property | Type | Description |
|---|---|---|
| Name | `String` | Preset label (e.g. "Exam Week", "Standard Week") |
| Days | `[Day: [Formula]]` | Mapping of 7 days to formula(s) |
| Status | `active` / `inactive` | Only one preset is active at a time |

---

## Rules

1. Each day can have **one or more** formulas assigned.
2. A day with **no formula** is unscheduled (no Today tab content).
3. Only **one week preset** is active at a time.
4. Week presets are managed in the [Lab Tab](../tabs/lab.md).

---

## Open Questions

- ❓ How do multiple formulas on the same day interact? Sequential? User picks at start?
- ❓ Can a week preset have different formulas for alternating weeks (e.g. week A / week B)?

---

## Related Docs

- [Formulas](formulas.md) — the schedules assigned to days
- [Lab Tab](../tabs/lab.md) — where week schedules are managed
