# Scheduling Algorithm

> How the app decides where to place tasks, what to shrink, and what to sacrifice.

---

## Overview

The scheduling algorithm handles two scenarios:

1. **Auto-placement** — when a new task is added without a specified time.
2. **Rebalancing** — when the schedule is disrupted (roadblock, overrun, early finish).

Both rely on the **priority** property of [Blocks](../concepts/blocks.md).

---

## Auto-Placement

When a user adds a task via [Roadblock](../features/roadblock.md) without specifying a time:

1. Scan remaining blocks for the **best fit** gap.
2. "Best fit" criteria (in order):
   - Minimizes disruption to high-priority blocks.
   - Nearest available slot of sufficient duration.
   - ❓ Adjacent to blocks of the same category (if applicable).
3. Insert the task and adjust surrounding blocks if needed.

---

## Rebalancing

Triggered when total scheduled time ≠ remaining day time. Causes:

- Type 2 block overrun (see [Time Flow](time-flow.md))
- Roadblock task insertion
- Early check-off time redistribution

### Shrinking

When the schedule is **over-committed**:

1. Calculate the overrun (extra minutes used).
2. Sort remaining blocks by priority (**ascending** — lowest priority shrinks first).
3. Proportionally reduce low-priority block durations.
4. If shrinking isn't enough, **sacrifice** (remove) the lowest-priority blocks until the schedule fits.

### Extending

When the schedule has **spare time** (early check-off):

1. Calculate reclaimed minutes.
2. Sort remaining blocks by priority (**descending** — highest priority extends first).
3. Proportionally extend high-priority block durations.

---

## Priority Levels

| Level | Meaning | Shrink/Sacrifice Order |
|---|---|---|
| High | Must happen today | Last to shrink, never sacrificed |
| Medium | Important but flexible | Shrinks moderately |
| Low | Nice to have | First to shrink, first to sacrifice |

> ❓ Exact numeric scale TBD (e.g. 1-5, 1-10).

---

## Open Questions

- ❓ Exact priority scale and default values
- ❓ Should the user confirm before blocks are sacrificed?
- ❓ How does rebalancing handle concurrent blocks?
- ❓ Can the user manually lock a block from being shrunk?

---

## Related Docs

- [Time Flow Logic](time-flow.md) — triggers that cause rebalancing
- [Blocks](../concepts/blocks.md) — priority property
- [Roadblock](../features/roadblock.md) — primary source of schedule disruption
