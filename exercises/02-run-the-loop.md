# 02 · Run the loop on a real problem — yours (Block 2 · hands-on #2 · 20 min)

**Format:** solo, then a 3-minute pair debrief.
**Goal:** run store → search → apply → record once, by hand, on something *you* solved this month.

All commands use today's database: `.nagual/nagual.db` in the repo root. From the repo root:

```bash
export NAGUAL_DB=$PWD/.nagual/nagual.db
```

## Step 0 — see what's already there (2 min)

```bash
nagual status --db-path $NAGUAL_DB
nagual knowledge search "flaky" --limit 5 --db-path $NAGUAL_DB
```

Five hundred-odd QE patterns came with the seed. Five more are masterclass starters. Every one of them is a
*hypothesis with a score*, not a fact.

## Step 1 — store something you solved this month (6 min)

A testing thing, ideally: a flake you diagnosed, an environment quirk, an oracle that caught a real bug.
The smaller and more concrete, the better.

```bash
nagual knowledge store "<the problem, in the words you'd search for later>" \
  --solution "<what actually worked, and why>" \
  --domain "qe.<area>" \
  --tags "<comma,separated>" \
  --confidence 0.7 \
  --db-path $NAGUAL_DB
```

Note the ID it prints. Your pattern is now tier **Booster**, reward 0.5 — unproven.

> Write the problem in *symptom* words (what a colleague sees), not *root-cause* words (what you found).
> Full-text search has no synonyms: `tokio` ≠ `tokio-runtime`. Future-you searches by symptom.

## Step 2 — get it back (3 min)

```bash
nagual knowledge search "<two or three of your words>" --limit 5 --db-path $NAGUAL_DB
```

Did it come back? If not, that's the most useful thing you'll learn today — whose vocabulary did you store
it in? Store it again with better words. (Don't delete the old one; consolidation will merge them later.)

## Step 3 — tell it the truth (4 min)

Pretend a week passed and you applied the pattern. Record what happened — honestly:

```bash
# it worked
nagual learn record <id> success --feedback "worked on CI too" --db-path $NAGUAL_DB

# it didn't — and you must say why (specification | misalignment | verification | resource | unknown)
nagual learn record <id> failure --failure-mode verification \
  --feedback "couldn't tell whether the fix took — no log access" --db-path $NAGUAL_DB
```

`partial` and `skip` exist too. Success moves reward up a little; failure moves it down a lot (in the build we ship, one failure took a fresh pattern from 0.50 to 0.20). The asymmetry is deliberate: wrong-confident beliefs cost more than uncertain ones.

## Step 4 — look at what changed (2 min)

```bash
nagual knowledge get <id> --db-path $NAGUAL_DB
nagual learn insights --windows 7d --db-path $NAGUAL_DB
```

## Debrief with your pair (3 min)

1. Did your pattern come back on search? If not — whose vocabulary did you store it in?
2. What tier is it in, and what would it take to reach **Reflex** (reward ≥ 0.9 plus reuse)?
3. Which MAST failure mode would your last *real* failure get? Argue about it.

The integrity rule: never record `success` you didn't observe, never record `failure` for a pattern you
didn't apply. If you lie to your memory, it will confidently recommend your lies back to you.
