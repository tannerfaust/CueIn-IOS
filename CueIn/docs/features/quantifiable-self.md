# Quantifiable Self (QS)

> Structured daily data input — track metrics about yourself beyond what the schedule captures.

---

## Overview

QS is the second mode of the [Monitor Tab](../tabs/monitor.md). It provides a list of **data rows** that the user fills in daily to track personal metrics (wake-up time, sleep, habits, etc.). The concept borrows from the Quantified Self movement but is redesigned for simplicity and automation.

---

## Data Row Properties

Each row represents one metric to track:

| Property | Type | Description |
|---|---|---|
| Name | `String` | Label (e.g. "Wake-up Time", "Junk Food") |
| Input Type | see below | How the user enters data |
| Notification Trigger | `on_first_log` / `scheduled` / `none` | When the user is prompted |
| Automation | `automatic` / `proactive` | Whether input is captured automatically or entered manually |

---

## Input Types

| Type | Description | Example |
|---|---|---|
| **Time** | Time picker | Wake-up time |
| **Number** | Numeric input | Hours of sleep, glasses of water |
| **True/False** | Toggle (with optional default-true subsetting) | Alcohol today? (default: No) |
| **Text** | Free-form text | Notes, journal entries |
| **One-of-Few** | Pick from predefined options | Mood: 😊 😐 😞 |

### True/False — Default-True Subsetting

For habit tracking of *irregular* events (e.g. alcohol, junk food):
- Default state is **True** (meaning "yes, I was good / didn't do it").
- User proactively flips to **False** only when the event occurs.
- Useful for tracking negative habits without daily input burden.

---

## Notification Triggers

| Trigger | Behaviour |
|---|---|
| `on_first_log` | Pop-up appears the first time the user opens the app that day |
| `scheduled` | Notification at a user-set time |
| `none` | No prompt — user goes to the QS page manually |

---

## Automation

| Mode | Example |
|---|---|
| **Automatic** | Pressing "Start" in Today tab auto-fills wake-up time in QS |
| **Proactive** | User manually selects/enters the value |

---

## Journal

Accessible from the QS page. The journal provides a day-level view showing:
- Mood, productivity, focus ratings
- What happened that day and what influenced the outcomes
- ❓ Structure: free text vs. structured prompts TBD

---

## Custom Rows

Users can **add their own rows** with a custom name, input type, notification trigger, and automation setting.

---

## Open Questions

- ❓ Is the journal free-form or templated?
- ❓ Are there visualizations per QS metric (trend lines, calendars)?
- ❓ Can QS data feed into Stats averages or Data Lab?

---

## Related Docs

- [Monitor Tab](../tabs/monitor.md) — parent tab
- [Stats](stats.md) — the other mode of Monitor
