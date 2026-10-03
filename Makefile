SHELL := /bin/bash
ROOT  := $(shell pwd)
export PATH := $(HOME)/.local/bin:$(HOME)/.cargo/bin:$(PATH)

.PHONY: check reset seed ironpets nagual-ui ruflo-proxy setup smoke help

check:        ## verify every tool is installed and reachable
	@bash .devcontainer/verify.sh

setup:        ## (re)run the full post-create setup
	@bash .devcontainer/post-create.sh

ruflo-proxy:  ## install and verify the optional Ruflo Meta-Proxy
	@bash .devcontainer/setup-ruflo-proxy.sh

reset:        ## wipe + reseed both memory systems
	@bash scripts/reset.sh

seed:         ## reseed without wiping
	@bash scripts/seed-fleet-memory.sh && bash scripts/seed-nagual.sh

ironpets:     ## start Iron Pets backend (:3001) and frontend (:3000) in tmux
	@tmux new-session -d -s ironpets -n backend  "cd workspace/iron-pets/src/iron-pets/backend  && DATABASE_URL=$$DATABASE_URL_IRONPETS npm run dev" \
	 && tmux new-window -t ironpets -n frontend "cd workspace/iron-pets/src/iron-pets/frontend && npm run dev" \
	 && echo "Iron Pets starting in tmux session 'ironpets' — attach with: tmux attach -t ironpets"

nagual-ui:    ## (re)start the Nagual dashboard on :3333
	@pkill -f "[n]agual serve" 2>/dev/null || true
	@cd .nagual && nohup nagual serve --port 3333 --db-path $(ROOT)/.nagual/nagual.db > serve.log 2>&1 &
	@echo "Nagual dashboard → http://localhost:3333"

smoke:        ## facilitator pre-flight: run every exercise command, then reset
	@bash scripts/smoke-exercises.sh

help:
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ —/'
