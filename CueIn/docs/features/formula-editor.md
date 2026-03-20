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
| **Block List** | Ordered list of blocks — drag to reorder |
| **Block Inspector** | When a block is selected, configure its properties |

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
