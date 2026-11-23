# ------------------------------------------------------------------------------
# Git Worktree Justfile Include
# ------------------------------------------------------------------------------
# Install as Justfile.wt.just, then in the Justfile:
#   import 'Justfile.wt.just'
# ------------------------------------------------------------------------------

# Start worktree environment in foreground
wt-up port="":
    scripts/worktree-dev.sh up {{ if port != "" { "--port " + port } else { "" } }}

# Start worktree environment in background (waits for health)
wt-start port="":
    scripts/worktree-dev.sh up -d {{ if port != "" { "--port " + port } else { "" } }}

# Stop app and containers (data kept)
wt-stop:
    scripts/worktree-dev.sh stop

# Remove containers (purge=true also deletes volumes and slot state)
wt-down purge="false":
    scripts/worktree-dev.sh down {{ if purge == "true" { "--purge" } else { "" } }}

# Remove containers, volumes and slot state (destructive)
wt-clean:
    scripts/worktree-dev.sh clean

# Inherit unversioned files from the main checkout
wt-sync:
    scripts/worktree-dev.sh sync

# Display slot, ports, URLs, and status
wt-info:
    scripts/worktree-dev.sh info

# Output shell exports: eval "$(just wt-env)"
@wt-env port="":
    scripts/worktree-dev.sh env {{ if port != "" { "--port " + port } else { "" } }}

# Run WT_TEST_CMD (or a health check) against this worktree
wt-test:
    scripts/worktree-dev.sh test
