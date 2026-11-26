# ------------------------------------------------------------------------------
# Git Worktree Universal Makefile Include
# ------------------------------------------------------------------------------
# Install as Makefile.wt.mk, then in the project Makefile:
#   -include Makefile.wt.mk
# Optional: `make wt-up PORT=3000` forces the app port (sticky until wt-clean).
# ------------------------------------------------------------------------------

PORT ?=
SERVER_PORT ?=

WT_PORT_ARG := $(firstword $(PORT) $(SERVER_PORT))
WT_ARGS := $(if $(WT_PORT_ARG),--port $(WT_PORT_ARG),)

-include .worktree-dev/slot.env

.PHONY: wt-up wt-start wt-stop wt-down wt-clean wt-info wt-env wt-sync wt-test

wt-up: ## Start worktree environment in foreground (auto-syncs unversioned files)
	scripts/worktree-dev.sh up $(WT_ARGS)

wt-start: ## Start worktree environment in background (waits for health)
	scripts/worktree-dev.sh up -d $(WT_ARGS)

wt-stop: ## Stop app and containers (data kept)
	scripts/worktree-dev.sh stop

wt-down: ## Remove containers (PURGE=1 also deletes volumes and slot state)
	scripts/worktree-dev.sh down $(if $(PURGE),--purge,)

wt-clean: ## Remove containers, volumes and slot state (destructive)
	scripts/worktree-dev.sh clean

wt-sync: ## Inherit unversioned files (.worktreeinclude) from the main checkout
	scripts/worktree-dev.sh sync

wt-info: ## Display slot, ports, URLs, status
	scripts/worktree-dev.sh info

wt-env: ## Output shell exports: eval "$$(make -s wt-env)"
	@scripts/worktree-dev.sh env $(WT_ARGS)

wt-test: ## Run WT_TEST_CMD (or a health check) against this worktree
	scripts/worktree-dev.sh test
