# Desktop candidate UI direction

Design note derived from the approved goal/management plans and current `Views/Theme.swift`, not a new product scope or visual acceptance result. No UI code or screenshots were changed/captured for this note.

## Subject and one job

An AI-native independent creator brings a concrete goal into a personal camp, works with the coach and cows, and accepts an actual verified result. The camp's primary job is to make the next real action obvious. Knowledge feeding remains a distinct secondary path. Preserve the existing pixel ranch identity and assets; do not replace it with a generic analytics dashboard or a new web-style design system.

Use the frontend-design skill for hierarchy, consistent verbs, and actionable error/empty states. The Product Design router was inspected but not activated: this is implementation in an established native code/visual target, not a requested prototype, visual exploration, URL clone or new audit. No image generation or user choice of new visual variants is needed.

## Existing tokens, deliberately retained

| Role | Existing light / dark values | UI use |
| --- | --- | --- |
| Camp.canvas | #F7F1E6 / #1F1813 | Stable camp background |
| Camp.surface | #FFFCF5 / #2B211A | Task/understanding content |
| Camp.ink | #3B3128 / #F0E6D4 | Primary reading |
| Camp.ember | #DE7738 / #E8894C | One primary available action |
| Camp.creek | #4A7FA6 / #7FA8C9 | Actually executing work |
| Camp.amber | #DD9F35 / #E6B04F | Explicitly awaiting the user |

Continue the existing moss completion and charcoalRed failure tokens for their existing semantic roles; no ad-hoc green-success or red-error palette. Never communicate status by color alone. Reuse Camp card radii/layout breakpoints and adaptive appearance.

Typography: existing native title2/title3 weight hierarchy for camp/goal titles; native system body for Chinese questions, answers and criteria; native monospaced utility text for trace/hash/evidence identities. Derive sizes from the existing view styles and accessibility settings rather than downloading new fonts or shrinking long technical text to fit. Long criteria and errors wrap; identities can disclose detail without overwhelming the primary action.

## Layout and signature

The distinctive element remains a small pixel-ranch work scene paired with the cow's **actual camp-scoped task state**. It is not an ornamental success animation. Keep the surrounding workspace calm and legible.

```text
Camp / goal breadcrumb                         Manage camp
What do you want to finish?            [Work with coach]
Add knowledge materials  ·  Existing missions

Needs your attention                 Actual cow activity
one question / one decision           state + linked task

Goals                                Camp results
truthful persisted states            artifacts + verification
```

Goal detail uses the same content column: original intent → the current question or editable understanding → the exact confirmation/contract → execution or outcome evidence. These sections represent real persisted states, not decorative numbered milestones. In a narrow native window, stack supporting activity/evidence below the task and retain the primary action; use the existing real-window breakpoints. Do not introduce a separate mobile product.

## Critique and interaction rules

The warm paper/ember palette would be a generic default on an unrelated dashboard; here it is an explicit established camp identity. Preserve it rather than claiming it is a new aesthetic invention. Remove generic KPI tiles, fake progress percentages, invented model dialogue and decorative timeline steps. The distinguishing content is the user's actual goal, one coach question and work/evidence provenance.

Every view names what the user controls: “与教练梳理”, “确认并开始”, “重新载入运行配置”, “归档营地”, “恢复营地”, “移除这头牛”. Archive never says delete. Failure keeps the input and offers only its typed authorized recovery. A committed action with failed refresh remains committed and does not offer a duplicate mutation. Disable duplicate actions while pending, not the whole application; keep keyboard focus and clear accessible labels. Preserve existing reduced-motion behavior and do not add ambient animation in this scope.

This note guides later D/management implementation after the runtime gate. Final assessment still requires the actual isolated App at ordinary and compact window sizes, keyboard interaction, light/dark appearance, failure recovery and pending-state screenshots; source inspection is not visual QA.
