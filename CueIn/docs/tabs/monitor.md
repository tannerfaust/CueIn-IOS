# Monitor Tab

> Analytics & self-tracking — view your performance data and log daily inputs.

---

## Overview

The Monitor tab has **two modes**, toggled via a switch in the top-right corner:

| Mode | Purpose |
|---|---|
| **Stats** | Visual analytics — streaks, graphs, averages |
| **QS** (Quantifiable Self) | Daily structured data input and journaling |

---

## Stats Mode

### UI Layout (top → bottom)

| Section | Description |
|---|---|
| **Consistency View** | GitHub-style heatmap of the last 30 days. Square brightness = formula adherence. Tap to toggle to a **7-day bar chart** (colored columns showing daily efficiency %) |
| **Averages** | Per-category average durations (e.g. *Work — avg 11 h*) with expandable subcategory breakdowns (e.g. *Deep Work — 4 h, Shallow Work — 3 h*) |
| **Data Lab** | Exploratory data tools — lets users play with their stats like a personal data-science sandbox |

### Consistency View Details

| View | Visual | Default range |
|---|---|---|
| **Calendar Heatmap** | Grid of small squares, brightness = adherence % | Last 30 days |
| **7-Day Bar Chart** | Vertical columns per day, colour-coded | Last 7 days |

### Averages

- Grouped by **category** (Work, Sport, Study…).
- Each category expands to show **subcategory** averages.
- Example:
  ```
  Work          avg 11 h/day
    ├─ Deep Work    4 h
    ├─ Shallow Work 3 h
    └─ Creative     4 h
  Study         avg 3 h/day
    ├─ CS           1.5 h
    ├─ Math         1 h
    └─ Physics      0.5 h
  ```

---

## QS Mode

See full spec → [Quantifiable Self](../features/quantifiable-self.md)

Summary: a list of **data rows** the user fills in daily (wake-up time, sleep, junk food, custom rows). Supports multiple input types and notification triggers.

Also provides access to the **Journal** — a daily reflection showing mood, productivity, focus, and what events shaped the day.

---

## Open Questions

- ❓ What tools/charts are available in Data Lab?
- ❓ Can users set custom date ranges for the consistency view?
- ❓ How is the journal structured (free text vs. prompts)?

---

## Related Docs

- [Stats](../features/stats.md) — deeper dive into analytics
- [Quantifiable Self](../features/quantifiable-self.md) — QS system spec
- [Blocks — Categories](../concepts/blocks.md#categories) — category/subcategory definitions
