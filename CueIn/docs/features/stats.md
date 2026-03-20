# Stats

> Visual analytics — streaks, consistency, averages, and data exploration.

---

## Overview

Stats is the first mode of the [Monitor Tab](../tabs/monitor.md). It gives users a visual understanding of how consistently they follow their formulas and how they allocate time across [Categories](../concepts/blocks.md#categories).

---

## Sections

### 1. Consistency View

Two togglable visualizations of recent adherence:

| View | Visual | Default Range |
|---|---|---|
| **Calendar Heatmap** | Grid of small squares (GitHub-style). Brightness = formula adherence % | Last 30 days |
| **7-Day Bar Chart** | Colour-coded vertical bars per day. Height = daily efficiency % | Last 7 days |

**Adherence %** = how closely the user followed the scheduled formula (blocks completed on time / total blocks).

### 2. Averages

Per-category average durations, each expandable into subcategories.

```
Work           avg 11 h/day
  ├─ Deep Work     4 h
  ├─ Shallow Work  3 h
  └─ Creative      4 h
Sport          avg 1.5 h/day
  ├─ Cardio        0.5 h
  └─ Resistance    1 h
```

### 3. Data Lab

An exploratory section where users can:
- ❓ Build custom charts and queries against their data
- ❓ Compare time periods
- ❓ Correlate QS inputs with formula adherence

*Details TBD — this is a future-facing feature area.*

---

## Data Sources

| Source | What it provides |
|---|---|
| Block check-offs | Completion times, adherence, duration accuracy |
| Categories / Subcategories | Grouping for averages |
| [QS Data](quantifiable-self.md) | Potential correlation inputs |

---

## Open Questions

- ❓ Full Data Lab feature set
- ❓ Can users export stats (CSV, PDF)?
- ❓ Streak mechanics — what counts as maintaining a streak?

---

## Related Docs

- [Monitor Tab](../tabs/monitor.md) — parent tab
- [Blocks — Categories](../concepts/blocks.md#categories) — where category data comes from
- [Quantifiable Self](quantifiable-self.md) — companion data source
