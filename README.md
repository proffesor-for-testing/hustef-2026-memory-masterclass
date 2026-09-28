# Memory as a Quality Signal — HUSTEF 2026 masterclass

*Building agents that learn from their own mistakes.*
Dragan "Profa" Spiridonov · HUSTEF 2026, Budapest · 100-minute deep dive

> An agent without memory isn't an agent; it's an expensive script that forgets everything the moment
> you close the terminal.

This repo is everything you need for the hands-on parts: a ready-made development environment, the two
memory systems we work with, a demo codebase with a known bug, seeded data, and the exercises in order.
Nothing here needs an API key, and nothing sends your data anywhere.

## Get a working environment (pick one)

**GitHub Codespaces — zero install.** Click *Code ▸ Codespaces ▸ Create codespace on main*. Choose a
4-core machine. First boot takes ~10 minutes (it compiles Nagual); prebuilds make it ~1 minute when
enabled.

**DevPod — your own Docker, any cloud or your laptop.**
```bash
devpod up github.com/proffesor-for-testing/hustef-2026-memory-masterclass --ide vscode
```

**VS Code Dev Containers — local Docker.** Clone, open the folder, accept *Reopen in Container*.
Needs Docker Desktop (or Docker Engine) running and ~8 GB RAM free.

All three read the same `.devcontainer/` — you get identical tools whichever you choose. When it's up:

```bash
make check
```

## What's inside the container

| Tool | Why it's here |
|---|---|
| Node 20, Rust, Python 3.12 | runtimes for the three projects |
| `claude` (Claude Code) and `codex` (OpenAI Codex CLI) | coding agents, for the optional "drive the fleet" demo — bring your own login |
| `aqe` — [agentic-qe](https://github.com/proffesor-for-testing/agentic-qe) | the fleet and its **operational memory** (Block 1) |
| `nagual` — [nagual-qe](https://github.com/proffesor-for-testing/nagual-qe), built from source | the self-learning **meta-memory** (Block 2) |
| ONNX Runtime + all-MiniLM-L6-v2 | local 128-d embeddings for `nagual knowledge search --semantic` — nothing leaves the container |
| [Iron Pets](https://github.com/proffesor-for-testing/iron-pets-by-jarvis) + Postgres + Redis | the demo e-commerce app with the cart-total bug |
| `gh`, `jq`, `sqlite3`, `tmux`, `rg` | the small tools the exercises use |

## The session

| Time | Block | Hands-on |
|---|---|---|
| 0:00 | Why memory — the frozen-agent problem, and the weekly tax you pay without it | — |
| 0:15 | **Block 1** · Operational memory in the Agentic QE Fleet | [01 · Read a fleet's mind](exercises/01-read-a-fleets-mind.md) (15 min, pairs) |
| 0:45 | **Block 2** · Nagual QE — the learning loop, scoring, failure classification | [02 · Run the loop](exercises/02-run-the-loop.md) (20 min, solo + debrief) |
| 1:20 | **Block 3** · Closing the loop in your own workflow | [03 · Close the loop](exercises/03-close-the-loop.md) (guided) |
| 1:35 | Wrap — your memory-architecture starter | — |

Start with [00 · Check your setup](exercises/00-check-your-setup.md).

## Layout

```
.devcontainer/    devcontainer.json, docker-compose.yml, Dockerfile, post-create/post-start, verify
exercises/        00 → 03, in order
examples/hooks/   write gate, outcome-recording hook, preload script, Claude Code settings example
scripts/          seed-fleet-memory.sh, seed-nagual.sh, reset.sh
workspace/        the three project repos (cloned on first boot — not committed here)
.nagual/          your Nagual database for the day (created on first boot)
```

## Handy commands

```bash
make check     # is everything installed and reachable?
make reset     # wipe + reseed both memory systems (between attempts, or between sessions)
make ironpets  # start the Iron Pets app on :3000 / :3001 (optional — only for the UI demo)
make nagual-ui # (re)start the Nagual dashboard on :3333
make smoke     # facilitator pre-flight: run every exercise command, then reset
```

## Taking it home

Everything in `examples/hooks/` is meant to be copied into your own project. The write gate is 30 lines
of shell; the outcome hook is a Claude Code `PostToolUse` hook; the preload script is a `nagual` query.
Start with one workflow and one outcome record. That's the whole loop.

Slides, the talk, and more writing: [forge-quality.dev](https://forge-quality.dev) ·
Questions after the conference: [linkedin.com/in/spiridonovdragan](https://linkedin.com/in/spiridonovdragan)

MIT licensed — see [LICENSE](LICENSE).
