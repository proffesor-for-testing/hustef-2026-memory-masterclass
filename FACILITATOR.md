# Facilitator guide (not for participants — but nothing here is secret)

## Before the session

- Enable **Codespaces prebuilds** on `main` a day before (Settings ▸ Codespaces ▸ Prebuilds). Without them,
  first boot is ~10 min per participant while Nagual compiles. With them, ~1 min.
- Bring the repo on a USB stick too (`git bundle create masterclass.bundle --all`) for the person whose
  laptop can't reach GitHub.
- Terminal at 28–32 pt, high-contrast theme. `tmux` is installed for split panes.
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
| `nagual` missing in someone's environment | `NAGUAL_SKIP_BUILD=0 bash .devcontainer/post-create.sh` — or pair them with a neighbour; the exercise is pairs anyway |
| `aqe memory list` shows 0 entries | `make reset` (re-inits `.agentic-qe` in Iron Pets and reseeds) |
| Semantic-indexing warning on `aqe memory store` | Expected — no embedder endpoint configured. Pattern (glob) search is what the exercise uses. |
| Iron Pets won't start | It's only for the UI demo; the memory exercises never touch it. Skip it. |
| Codespaces quota / no GitHub account | DevPod on the presenter laptop, screen-shared; or the USB bundle + local Docker |
| Room network dies | `cat` saved outputs from `examples/outputs/` and discuss |

## Known quirks (verified 27 Sep 2026)

- **nagual-qe `main` does not compile.** Dependabot merged breaking bumps (sha3 0.12 in #26, sqlx 0.9 in #29).
  The devcontainer pins `54f6932`, the last green commit. Fix main, then bump the pin in `post-create.sh`.
- **Reward step.** The slides say −0.15 per failure; the shipped build dropped a fresh pattern 0.50 → 0.20 on
  one `failure`. Say "down a lot, up a little" rather than quoting the number, or fix the slide.
- **`aqe memory store` warns about semantic indexing** — no embedder endpoint. Harmless; glob search is what
  the exercise uses.
- **`nagual` prints JSON log lines on stdout.** The devcontainer installs a wrapper that strips them
  (`nagual-bin` is the raw binary).
- **`nagual knowledge list --domain X --limit N` applies the limit before the domain filter** — with a small N
  it returns nothing. Use `search`, or `--limit 5000` and cut the output (see `examples/hooks/preload-patterns.sh`).
  Worth a bug report against nagual-qe (`run_list` in `src/cli/knowledge.rs`).
- **Nagual defaults to `./nagual.db` in the current directory.** Every command in the exercises passes
  `--db-path $NAGUAL_DB`; if someone "loses" their patterns, they ran a command without it from another folder.

## Optional demos (facilitator machine only)

- **Local judge (Block 2):** `ollama pull qwen3:8b` on your own Mac beforehand. Not in the devcontainer —
  too heavy for participants, and the point is "it runs on your machine", not theirs.
- **Nagual dashboard:** `make nagual-ui` → forwarded port 3333.
- **Drive the fleet with Claude Code:** `cd workspace/iron-pets && claude` then `/aqe-analyze` — needs
  your own login; do this on the projector, not per participant.
