# M2 Live Smoke — Two-Card Dependent Mission

Purpose: verify the real app/API path for the M2 acceptance sentence: two-card dependent action end to end, downstream cold-start work begins from upstream handoff.

## Preconditions

- API key is saved in Settings.
- At least two regular companions exist, with distinct models if model routing is being checked.
- A writable workspace directory is available.

## Script

1. Open the app and go to New Action.
2. Enter a goal that naturally splits into two dependent cards, for example:
   `Create a short research note: first gather three facts into facts.md, then write a final conclusion from facts.md.`
3. Select two companions in order.
4. Choose the workspace directory.
5. Start the action.
6. Wait without manual intervention until the mission reaches the closeout-ready state.
7. Confirm the card list shows the upstream card completed before the downstream card.
8. Confirm the downstream card progress references the upstream handoff or `facts.md`.
9. Confirm the artifact section contains `facts.md`.
10. Click the Finder reveal action for the artifact and confirm the durable copy exists.
11. Click Close Out.
12. Confirm the mission reaches accepted.

## Pass Criteria

- Planning creates at least two cards with a dependency.
- Only one card runs at a time.
- The downstream card starts after the upstream card is done.
- The downstream prompt has the upstream summary and artifact path.
- The artifact is copied to durable storage and Finder reveal works.
- Closeout moves the mission to accepted.

## Known Sandbox Note

This live smoke is for the real machine with API access. The offline golden-path test covers the same kernel path with `MockProvider`.
