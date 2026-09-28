# 03 · Close the loop in your own workflow (Block 3 · 15 min, guided)

**Format:** follow along on the projector; copy the pieces you want into your own repo afterwards.
**Goal:** see the four-step architecture running end to end — verify *before* memory writes, record
outcomes *automatically*, preload proven patterns *next run*.

## The loop, assembled

```
1 · RUN      agents work; operational memory coordinates; every claim carries evidence
2 · VERIFY   a gate checks claims against artifacts — BEFORE anything is written as a result
3 · RECORD   outcomes (with MAST-classified failures) flow to Nagual; a judge scores what's worth keeping
4 · PRELOAD  the next run starts with the highest-tier patterns injected
```

## Piece 1 — the write gate (`examples/hooks/memory-write-gate.sh`)

A shell gate of under 30 lines: refuses to store an entry as a *result* unless every path in its `evidence` list
exists. Everything else is stored under `claims/` instead. Run it against the bare claim from hands-on #1:

```bash
cd workspace/iron-pets          # the gate writes into the fleet memory that lives here
bash ../../examples/hooks/memory-write-gate.sh test-plan/cart \
  '{"claim":"cart-total fix verified","evidence":[],"agent":"qe-test-architect"}'
```

It lands under `claims/test-plan/cart`, not `test-plan/cart`. The gate can't be argued with.

## Piece 2 — record outcomes at tool boundaries (`examples/hooks/record-outcome.sh`)

A Claude Code `PostToolUse` hook: when a test command exits, it records `success` or `failure` against the
pattern id named in `.nagual/current-pattern`. Wire it in `.claude/settings.json` (example in
`examples/hooks/claude-settings.example.json`). Codex users (or CI): run the test command through it —
`bash examples/hooks/record-outcome.sh -- npm test`. The wrapped command's exit code is passed through, so a
red run stays red.

## Piece 3 — preload (`examples/hooks/preload-patterns.sh`)

Before a run, pull the top-tier patterns for the domains you're about to touch and drop them into the
agent's context file:

```bash
bash examples/hooks/preload-patterns.sh qe.flaky qe.regression > .agentic-qe/PRELOAD.md
```

## What to take home

- **This week:** add an outcome record at the end of ONE workflow. A CSV counts.
- **This month:** split operational memory from meta-memory. Put a gate before every memory write. TTLs on operational state.
- **This quarter:** score patterns by outcomes; classify failures; read the calibration report — then argue with it.

The memory doesn't do the testing. It stops you re-buying the same knowledge every week.
