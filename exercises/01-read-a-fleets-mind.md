# 01 · Read a fleet's mind (Block 1 · hands-on #1 · 15 min)

**Format:** pairs. One types, one reads. Swap halfway.
**Goal:** read operational memory *as an auditor, not a consumer* — and find the one entry that is a bare claim.

## The scenario

The Agentic QE fleet just ran against Iron Pets (run `r-0417`). It left its working memory behind in the
`aqe` namespace: coverage numbers, a test plan, a flake history, a risk note, an environment quirk — and a
quality-gate verdict that says **PASSED**.

Somewhere in there is a claim with nothing behind it. The gate trusted it. You shouldn't.

## Step 1 — what does the fleet remember right now? (3 min)

```bash
cd workspace/iron-pets
aqe memory list --namespace aqe
```

You'll see a handful of keys. Notice the *shape*: `area/thing`. The namespace is the fleet's shared
blackboard — every agent reads and writes here instead of messaging every other agent.

> Write down: which keys look like **results**, and which look like **decisions**?

## Step 2 — pull everything about the cart (4 min)

```bash
aqe memory search --pattern "*cart*" --namespace aqe
```

Note the leading `*` — keys are `test-plan/cart`, `coverage/cart-service`, so `cart*` would match nothing.
(Yes, we learned that the hard way. That's what memory is for.)

## Step 3 — inspect each entry: claim or evidence? (5 min)

```bash
aqe memory get --key coverage/cart-service --namespace aqe --include-metadata
aqe memory get --key test-plan/cart        --namespace aqe --include-metadata
aqe memory get --key flaky/cart-total-e2e  --namespace aqe --include-metadata
```

Each value is a small JSON object with a `claim` and an `evidence` list. One of them has
`"evidence": []`.

> Say it out loud when you find it. First pair to name the key and explain *why the gate is now wrong*
> wins nothing but respect.

## Step 4 — the payoff (3 min, together)

```bash
aqe memory get --key quality-gate/r-0417 --namespace aqe
```

The gate consumed the bare claim as if it were verified. That is memory poisoning: one unverified entry,
and now every downstream agent — and the release decision — inherits it.

**The fix is architectural, not behavioural:** verification runs *before* the memory write, and entries
without evidence are stored as claims, never as results. We'll build that gate in Block 3.

## If you have time

Store your own entry with evidence, then one without, and see how quickly the difference disappears
once you stop looking:

```bash
aqe memory store --key test-plan/wishlist --namespace aqe \
  --value '{"claim":"wishlist add/remove covered","evidence":["tests/wishlist.spec.ts"],"agent":"you"}'
```

Commands verified against agentic-qe 3.14.4 (the version the devcontainer installs) — `aqe memory store | get | search | list | delete | share | usage`.
