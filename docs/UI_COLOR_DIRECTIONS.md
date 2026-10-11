# Gym Log — fresh UI directions

October 10, 2026. **Studio is now the user-selected direction.** The initial comparison below is retained as design history. See [Studio refinement](STUDIO_REFINEMENT.md) for compact headings, user-controlled lineups and theme architecture; native implementation remains pending.

## User direction

The user explicitly asked to leave the current UI behind and develop a richer, entirely new visual and UX direction. They rejected the screenshot treatments: a coral vertical callout stripe and a coral stroke along the rounded top of a set card. Neither is permitted in this proposal. The new direction supersedes the earlier wireframe's visual styling; established behavioral requirements remain.

The user also asked for deliberate color theory and the strongest possible palette. Color choice is contextual, not objectively universal. The recommendation below is a design judgment supported by contrast measurements, not a claim that a hue improves exercise performance or is scientifically the best.

## Original recommendation: Velocity (superseded by user selection)

An editorial training interface with open sections, large editable numbers, fine neutral separators and a dominant pill-shaped completion action. Previous performance sits on a plain line rather than a callout card. The active set has no enclosing outlined card. Weight and reps have separate large fields and labeled decrement/increment controls. Completed sets appear beneath the primary action with Undo.

Navigation is proposed as Train / Plan / Progress, with Watch/settings in the header and session history accessible through Progress. This information architecture is for review, not an approved removal of existing History functionality. The preview shows only its latest saved session; a full history list and routine management remain required for production.

### Velocity palette

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | Porcelain `#F1F3F8` | Ink `#10151F` |
| Secondary surface | `#E3E8F2` | `#1D2738` |
| Main text | `#101B30` | `#EDF2FF` |
| Secondary text | `#515E72` | `#B0BED4` |
| Primary action | Electric blue `#234BDB` | Glacier `#9BB8FF` |
| Text on primary action | `#FFFFFF` | `#101B30` |
| Rest surface | `#DCE6FF` | `#273C65` |
| Neutral separator | `#C6CCDA` | `#354056` |

Color reasoning: a blue-biased neutral family creates coherence without coloring every element. Saturated blue in light appearance and a lighter glacier tint in dark appearance preserve a strong action hierarchy. Dark-mode accents are lighter because their contrast requirements and surrounding luminance differ; the palette is not a mechanical inversion. Most screen area stays neutral. Accent is reserved for key actions and progress marks, not decoration around containers.

## Selected direction: Studio

A warmer interpretation using stone, olive and citron. Serif display typography, a solid tonal session tile and grouped set entry create a different composition and tone. Small functional text and numeric entry remain sans serif. The session tile is a solid fill with no accent outline or top stroke. The set sequence uses labeled pills, not color alone.

| Role | Light | Dark |
| --- | --- | --- |
| Canvas | Stone `#F5F2E9` | `#1C211B` |
| Secondary surface | `#E7E5D9` | `#2B3328` |
| Main text | Deep olive `#283529` | `#F1F3E6` |
| Secondary text | `#5C6658` | `#B9C3AE` |
| Primary action | Olive `#354C27` | Citron `#D6EF81` |
| Text on primary action | `#F6F8ED` | `#26331C` |
| Rest surface | `#E1EDBB` | `#3A4629` |
| Neutral separator | `#C8CCBC` | `#475140` |

Color reasoning: warm neutrals and related yellow-green hues create continuity across surfaces. Low saturation covers large areas; stronger value contrast identifies actions. Citron is restricted to dark-mode actions and selection, keeping it readable without flooding the interface. This is a subjective aesthetic alternative, not a claim of a calming psychological effect.

## Shared interaction and color rules

- Never use the rejected colored side stripes or rounded card-top strokes. Neutral horizontal separators are permitted.
- Keep one dominant action in each decision area. No decorative gradient borders, neon glows or colorful status badges on every row.
- Selection and completed states use text/checkmarks as well as color. Invalid entries have an explicit message; missing Watch data has a textual unavailable state.
- The app's coral mascot is unchanged. Exploring a new screen palette does not authorize replacing the icon. Reconcile icon/screen branding after direction approval.
- Preserve the previously approved behavior: user-chosen exercises/schedules; add without leaving search; explicit completion; undo; state continuity; API-driven production catalog and its cache policy; no fabricated Health measurements.
- Search data and routines in this isolated prototype are fixtures. Production filters still come from ExerciseDB, and the existing full taxonomy, Saved mode, failure states and multi-select review must remain even where this visual sample simplifies them.
- Stepper increments in the preview are 2.5 lb / one rep to demonstrate ergonomics. Production must retain units, precision and configurable increments; this is not an approved universal increment.
- A full production implementation must include editing set targets, all exercises in a routine, reordering, multiple routines, set types, optional effort, historical edits, keyboard-safe layout and expanded Watch states. Nothing in a simplified visual sample authorizes deleting these features.

## Accessibility basis and verification

The [W3C contrast criterion](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) specifies at least 4.5:1 for normal text and 3:1 for qualifying large text. The [use-of-color criterion](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html) requires information to be available beyond color alone. These are used as measurable web-preview checks, not a declaration of full native accessibility compliance.

Local browser checks inspected computed foreground/background pairs for visible enabled text in seven primary screens at 390 px. Minimum observed ratios by direction/appearance: Velocity light **5.35:1**, Velocity dark **7.98:1**, Studio light **4.75:1**, Studio dark **7.14:1**. No checked text pair fell below its applicable threshold. Disabled controls were excluded. This does not test every focus/pressed state, icon contrast, all overlays or native accessibility behavior.

Both concepts passed the sample search → select → details → add-without-dismissal flow, invalid entry, set completion/undo, rest adjustment/skip, save and computed summary checks. Seven primary screens at 320, 390 and 736 px in light and dark appearance, across both concepts, produced no detected horizontal overflow (84 layout states). No JavaScript errors were recorded. Rendered Velocity dark home, Velocity light workout and Studio light home were visually inspected.

Phone testing is still required for thumb reach, keyboard occlusion, glare, Dynamic Type, VoiceOver, long exercise names and accessibility scaling. Contrast compliance alone is insufficient to call the design best-in-class.

## Review artifact

[Standalone preview](designs/new-directions.html) · [Editable source](designs/new-directions.fragment.html)

The two concepts have independent sample state. Start a session, adjust the numbers, complete/undo a set and finish to see the flow. Use the screen selector to examine Plan, Search, Progress and Watch/settings. The host design controls can change appearance and previous-performance visibility. The rest timer is labeled a static preview. The prototype makes no API requests or Health connections and does not modify app data.
