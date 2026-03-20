# CueIn Documentation System

> This folder is the **single source of truth** for what CueIn is, how it works, and how every feature behaves.

---

## Folder Structure

```
docs/
├── README.md              ← You are here. Rules & navigation.
├── tabs/                  ← One file per bottom-navigation tab
│   ├── today.md
│   ├── lab.md
│   ├── monitor.md
│   └── profile.md
├── concepts/              ← Core domain objects explained
│   ├── formulas.md
│   ├── blocks.md
│   └── week-schedule.md
├── features/              ← Distinct user-facing features
│   ├── roadblock.md
│   ├── quantifiable-self.md
│   ├── stats.md
│   └── formula-editor.md
└── algorithms/            ← Logic & rules under the hood
    ├── time-flow.md
    └── scheduling.md
```

---

## How to Read These Docs

| Folder | Purpose | When to read |
|---|---|---|
| `tabs/` | Describes what the user **sees and does** in each tab | When designing UI or understanding user journeys |
| `concepts/` | Defines the **objects** that power the app (formulas, blocks…) | When you need to understand what something *is* |
| `features/` | Explains a specific **capability** end-to-end | When implementing or modifying a feature |
| `algorithms/` | Documents **logic and rules** the app follows internally | When writing or debugging core logic |

---

## File Format Rules

Every `.md` file follows this template:

```markdown
# Title

> One-line summary of what this page covers.

---

## Overview
Brief description (2-4 sentences).

## Key Properties / Elements
Tables or bullet lists of the thing's attributes.

## User Flows (if applicable)
Numbered step-by-step interactions.

## UI Layout (if applicable)
Visual structure described top-to-bottom, left-to-right.

## Rules & Logic (if applicable)
Bullet list of business rules and edge cases.

## Open Questions
Anything still unresolved — prefix with ❓.

## Related Docs
Links to other docs in this folder.
```

---

## Conventions

1. **Keep it flat** — avoid nesting deeper than `docs/<subfolder>/file.md`.
2. **One topic per file** — if a section grows beyond ~200 lines, split it.
3. **Link, don't duplicate** — reference other docs with relative links like `[Blocks](../concepts/blocks.md)`.
4. **Mark unknowns** — use `❓` for open questions and `⚠️` for known issues.
5. **Use tables** for properties, data types, and comparisons.
6. **Update, don't append** — when something changes, update the relevant section in place.
7. **Changelog not needed** — Git history is the changelog.

---

## Quick-Reference: Core Terminology

| Term | Definition |
|---|---|
| **Formula** | A predefined, customizable schedule for a full day |
| **Mini-Formula** | A small sub-schedule that lives inside a block (e.g. "Morning Routine") |
| **Block** | A single time slot within a formula — can be a task, placeholder, or group |
| **Week Schedule** | A 7-day layout that assigns formulas to each day |
| **Roadblock** | An interruption flow triggered when something unexpected happens |
| **Category** | A top-level label for a block (e.g. Work, Sport, Study) |
| **Subcategory** | A more specific label within a category (e.g. Deep Work, Cardio) |
| **QS** | Quantifiable Self — structured daily data input for self-tracking |
| **Stage** | A life phase defined in Profile (shown in Today tab header) |
