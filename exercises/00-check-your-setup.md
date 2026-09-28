# 00 · Check your setup (5 min, before we start)

Run this in the terminal:

```bash
make check
```

Every line should show a green ✔. Two yellow bullets about API keys are fine — you only need
a key if you want to drive the fleet with Claude Code or Codex during Block 1's optional demo.
The memory exercises themselves need **no** API key and send **nothing** to any cloud.

If `nagual` is missing, the Rust build didn't finish. Run it now — it takes 5–10 minutes and you
can keep reading:

```bash
bash .devcontainer/post-create.sh
```

If `fleet memory` or `nagual db` is missing:

```bash
make reset
```

## Three ways you may be running this

| You are in | How you got here | Notes |
|---|---|---|
| GitHub Codespaces | "Code ▸ Create codespace on main" | Everything ran already. 4-core machine recommended. |
| DevPod | `devpod up <repo-url> --ide vscode` | Same devcontainer, your own Docker. |
| VS Code Dev Containers | "Reopen in Container" | Needs Docker Desktop / Docker Engine running locally. |

## Where things live

```
workspace/agentic-qe/     the fleet (source, for reading)
workspace/iron-pets/      the demo e-commerce app — fleet memory lives in .agentic-qe/ here
workspace/nagual-qe/      the self-learning memory (source; the binary is ~/.local/bin/nagual)
.nagual/nagual.db         YOUR Nagual database for today
exercises/                this folder — do them in order
examples/                 hooks and pattern files you can copy into your own projects
```

Two terminals side by side work best: one in `workspace/iron-pets`, one in the repo root.
