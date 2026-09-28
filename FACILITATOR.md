# Facilitator guide (not for participants — but nothing here is secret)

## Before the session

- Enable **Codespaces prebuilds** on `main` a day before (Settings ▸ Codespaces ▸ Prebuilds). Without them,
  first boot is ~10 min per participant while Nagual compiles. With them, ~1 min.
- Bring the repo on a USB stick too (`git bundle create masterclass.bundle --all`) for the person whose
  laptop can't reach GitHub.
- Terminal at 28–32 pt, high-contrast theme. `tmux` is installed for split panes.
- The day before: `make smoke` in a fresh Codespace — it runs every participant command from exercises 00–03
  (plus the dashboard and Iron Pets) and resets afterwards. Read its output against the checklist at the top of
  `scripts/smoke-exercises.sh`.
- Run `make reset` in your own environment right before you start — the planted claim must be there.
- Backup recordings of both hands-on blocks in case the room network dies (record with `asciinema`).

## Timekeeping

| Clock | Block | Cue |
|---|---|---|
| 0:00 | Why memory (15) | "A week in QE" — ask which row is their Monday |
| 0:15 | Block 1 (30): anatomy 8 · so-what 5 · **hands-on 15** · debrief 2 | Laptops out at 0:23 |
| 0:45 | Block 2 (35): loop + anatomy 6 · scoring + MAST 7 · **hands-on 20** · debrief 2 | Laptops out at 0:58 |
| 1:20 | Block 3 (15): guided, projector only | run the write gate live against `test-plan/cart` |
| 1:35 | Wrap (5) | starter checklist; office hours offer |

## The planted claim (hands-on #1)

`test-plan/cart` in namespace `aqe` — `"evidence": []`, and `quality-gate/r-0417` consumed it.
Seeded by `scripts/seed-fleet-memory.sh`. The point to land: **the gate is now wrong, and nothing in the
fleet knows it.** Verification before memory writes is the architectural fix (Block 3, piece 1).

The `search --pattern` gotcha (`"*cart*"`, not `"cart*"`) is a deliberate teaching moment about search
vocabulary — it sets up hands-on #2's "whose words did you store it in?"

## Failure recovery

| Symptom | Do |
|---|---|
| `nagual` missing in someone's environment | `make setup` (re-runs post-create; ~2 min build on 4+ cores) — or pair them with a neighbour; the exercise is pairs anyway |
| `aqe memory list` shows 0 entries | `make reset` (re-inits `.agentic-qe` in Iron Pets and reseeds) |
| Semantic-indexing warning on `aqe memory store` | Expected — no embedder endpoint configured. Pattern (glob) search is what the exercise uses. |
| Iron Pets won't start | It's only for the UI demo; the memory exercises never touch it. Skip it. |
| Codespaces quota / no GitHub account | DevPod on the presenter laptop, screen-shared; or the USB bundle + local Docker |
| Room network dies | `cat` saved outputs from `examples/outputs/` and discuss |
| Dashboard on :3333 shows nothing | `make nagual-ui`, then check `.nagual/serve.log` |

## Known quirks (verified 28 Sep 2026, end-to-end in a fresh devcontainer)

- **nagual-qe is pinned** in `post-create.sh` to the 0.2.0 fix commit (build fix for the dependabot sha3/sqlx/axum
  bumps, one asymmetric reward rule incl. security failures, `knowledge list` pagination, logs on stderr, `nagual serve` startup + local auth, PII redaction on the
  HTTP read path). Override with `NAGUAL_QE_REF=<ref>`. Once the PR is merged, repin to the merge commit.
- **Reward steps (nagual-qe 0.2.0, matches slide 19 once it adds the security row):** success +0.10,
  partial +0.05, failure −0.15, security failure −0.30, clamped to [0, 1]. A fresh pattern: 0.50 → 0.35 on
  one failure, → 0.45 on a following success. `learn record` prints the step, so let the room read it off.
- **`flaky` ≠ `flakes`.** FTS5 has no stemming: `search "flaky"` does not find the cart starter pattern ("flakes").
  Exercise 02 turns this into the vocabulary point on purpose.
- **aqe is chatty.** agentic-qe prints ~90 init lines (stderr) per command. Interactive shells in the container
  filter the known chatter (`aqe` is a shell function; `command aqe …` gives raw output). A one-line
  `[WARN] … No model providers` is also filtered — harmless.
- **`aqe memory store` warns about semantic indexing** — no embedder endpoint. Harmless; glob search is what
  the exercise uses.
- **Nagual defaults to `./nagual.db` in the current directory.** Every command in the exercises passes
  `--db-path $NAGUAL_DB`; if someone "loses" their patterns, they ran a command without it from another folder.
- **Iron Pets frontend** needs `npm install --legacy-peer-deps` (eslint-config-next peer range); post-create does
  that. The backend has no migrations — post-create uses `prisma db push` + `prisma db seed`.

## Optional demos (facilitator machine only)

- **Local judge (Block 2):** `ollama pull qwen3:8b` on your own Mac beforehand. Not in the devcontainer —
  too heavy for participants, and the point is "it runs on your machine", not theirs.
- **Nagual dashboard:** `make nagual-ui` → forwarded port 3333.
- **Drive the fleet with Claude Code:** `cd workspace/iron-pets && claude` then `/aqe-analyze` — needs
  your own login; do this on the projector, not per participant.
