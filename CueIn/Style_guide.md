# Style guide — CueIn

Unified design direction: **native iPhone clarity** (Apple HIG) meets **Linear-style calm** — minimal chrome, structure you *feel* more than you see, and a dark-first, precision feel.

---

## Design principles

1. **iPhone-native first** — Use system layouts, safe areas, Dynamic Type, and standard patterns (tab bar, navigation stacks, sheets). The app should feel like it belongs on iOS, not a web port.
2. **Calm density (Linear)** — Pack information without noise: clear hierarchy, aligned grids, and **soft separators** instead of heavy boxes. Prefer one strong focal action over many competing buttons.
3. **Structure felt, not seen** — Borders and dividers are **low-contrast**; grouping comes from spacing, typography scale, and subtle background shifts — not thick outlines.
4. **Speed & precision** — Interactions are immediate; lists and schedules feel *scannable*. Use **monospace** sparingly for times, durations, and numeric metrics (Linear’s “tooling” vibe on data).
5. **Minimal decoration** — No gratuitous gradients or illustration unless they aid comprehension. Accent color is **restrained**: one primary accent for key actions and focus states.

---

## Visual language (Linear-inspired + iOS)

| Aspect | Direction |
|--------|-----------|
| **Theme** | **Dark mode default** (Linear’s Nordic-style deep grays). Light mode: clean off-white surfaces, not pure harsh white. Support both; test contrast in both. |
| **Surfaces** | Layered grays: base background → slightly elevated cards/sheets. Avoid loud shadows; use **1pt hairlines** or **very soft** elevation. |
| **Accent** | One primary accent (e.g. cool blue or subtle violet — keep saturation low). Secondary states use opacity and `secondaryLabel`-style hierarchy, not more colors. |
| **Corners** | **Moderate** corner radius (system `continuous` curves where available). Not bubbly; aligned with iOS large controls and sheets. |
| **Icons** | **SF Symbols** — outline, regular/medium weight; consistent sizing per context (toolbar vs. list). |

---

## Typography

- **Primary:** San Francisco (`.body`, `.headline`, `.title`) — respect **Dynamic Type** everywhere.
- **Emphasis:** Weight and size, not extra font families.
- **Data / time / metrics:** **Monospace** (e.g. `.monospacedDigit()` or system monospaced) for durations, clocks, and numbers in schedules — improves scanability and matches a “precision tool” feel.

---

## Layout & spacing

- **8pt grid** (4pt for fine tuning): consistent padding in lists and cards.
- **Generous vertical rhythm** between sections; **tight** spacing *within* a related group (e.g. one formula block).
- **Touch targets** ≥ 44×44 pt; keep tab bar and primary actions thumb-friendly.

---

## Components (unified behavior)

- **Navigation:** Standard `NavigationStack` + large titles where it helps orientation; avoid custom nav chrome that fights the system.
- **Lists:** Plain or inset grouped style as appropriate; separators **subtle** (system secondary separator colors).
- **Sheets & forms:** Use system sheet presentation; primary action clearly primary (one accent).
- **Empty states:** Short copy + single CTA — no clutter.
- **Feedback:** Haptics for meaningful completion (e.g. start day, finish block); keep animations **short** and purposeful.

---

## What to avoid

- Heavy drop shadows and thick borders on every card.
- Multiple competing accent colors.
- Custom typefaces for body text (breaks iOS cohesion and accessibility).
- Dense walls of text — schedules and metrics should **scan** in seconds.

---

## References (for designers & devs)

- [Apple Human Interface Guidelines — iOS](https://developer.apple.com/design/human-interface-guidelines/)
- [Linear — Brand guidelines](https://linear.app/docs/brand-guidelines) (palette/spirit: restrained, timeless UI)
- [Linear — Behind the latest design refresh](https://linear.app/now/behind-the-latest-design-refresh) (“structure should be felt not seen”)

*Update this file when you lock brand colors in asset catalogs or add a formal design token layer.*
