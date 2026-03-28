# Formula Editor

> The creation and editing interface for formulas and mini-formulas.

---

## Overview

The Formula Editor is opened from the [Lab Tab](../tabs/lab.md) whenever a user creates a new formula or taps an existing one to edit. It provides a minimalistic page for assembling [Blocks](../concepts/blocks.md) into a schedule.

---

## UI Layout

| Element | Description |
|---|---|
| **＋ Button** (top) | Add a new block to the formula |
| **Block List** | Ordered list of blocks — tap to edit, long-press drag to reorder, swipe for quick actions |
| **Block Inspector** | Sheet for configuring the selected block's properties |
| **Category Split** | Live calculation of how much scheduled time each category takes inside the formula |
| **Time Magnet Toggle** | Optional full-formula setting that rounds upcoming block starts to cleaner clock slots |

---

## Block Configuration Options

When adding or editing a block:

| Setting | Description |
|---|---|
| Name | Block label |
| Category | Select from pre-made categories |
| Subcategory | Add/select a subcategory |
| Duration | Set time length |
| Color | Choose visual color |
| Flow Logic | Type 1 or Type 2 (see [Time Flow](../algorithms/time-flow.md)) |
| Priority | Importance level for rearrangement |
| Mini-Formula | Optionally nest a mini-formula inside the block |
| Details | Free-text description |

## Current Editor Behaviour

1. Tap **＋** to add a block.
2. Tap an existing block to edit its name, duration, category, subcategory, priority, and flow logic.
3. Turn on **Time Magnet** when you want future block starts to align to rounder times.
4. Long-press a block row and drag it to rearrange the formula order.
5. Swipe a block row left to reveal quick actions such as edit, duplicate, and delete.
6. Watch the compact **Category Split** strip update live as blocks are added, edited, or moved.

---

## Supported Formula Types

| Type | Created via |
|---|---|
| **Full Formula** | Lab → ＋ → New Formula |
| **Mini-Formula** | Lab → ＋ → New Mini-Formula, or inline while editing a block |

---

## Open Questions

- ❓ Can the editor preview the formula as a timeline?
- ❓ Is there a validation step (e.g. "blocks exceed 16 h")?
- ❓ Can blocks be duplicated within the editor?

---

## Related Docs

- [Lab Tab](../tabs/lab.md) — where the editor is accessed
- [Formulas](../concepts/formulas.md) — what's being edited
- [Blocks](../concepts/blocks.md) — the items being added
