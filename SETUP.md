# Hull Setup Instructions

> **For the agent implementing hull.** Clone, structure, and wire the feature pipeline on top of keel.

## What hull is

hull is the active bridge between upstream pi-mono and the keel harness. It's not a static fork — it's a build pipeline:

```
pi-mono (upstream) ──pull──→ hull ──rewrite imports──→ features on keel
                                  ↑
                            sync script runs here
```

When pi is open: hull tracks upstream, syncs features. When pi closes: hull becomes the community upstream for features.

## Architecture — three repos

```
devexcelsior/keel           MPL-2.0   ← harness: ai + agent, un-ownable foundation
devexcelsior/hull           MIT       ← this repo: feature pipeline, tracks upstream
devexcelsior/helm           MIT       ← methodology: AGENTS.md, prompts, orchestration
```

## Workflow chunks

| # | Slug | What |
|---|---|---|
| 1 | `hull-clone` | Clone pi-mono, set origin to devexcelsior/hull, add upstream remote |
| 2 | `hull-strip` | Strip agent/ai packages (they live in keel now), keep features |
| 3 | `hull-rewire` | Rewrite feature imports to point at keel harness |
| 4 | `hull-sync` | Create sync-upstream.sh — daily cherry-pick of feature commits |
| 5 | `hull-readme` | Write README with architecture, license, sync instructions |
| 6 | `hull-build` | Build, verify, commit, push |

---

## 1. Clone and set up remotes

```bash
mkdir -p ~/keel-workspace && cd ~/keel-workspace

# Clone pi-mono directly (NOT a GitHub fork — keel already used the fork)
git clone https://github.com/badlogic/pi-mono.git hull
cd hull

# Point origin at the hull repo
git remote set-url origin https://github.com/devexcelsior/hull.git

# Track upstream for pulls
git remote add upstream https://github.com/badlogic/pi-mono.git

# Verify
git remote -v
# origin    https://github.com/devexcelsior/hull.git (fetch/push)
# upstream  https://github.com/badlogic/pi-mono.git (fetch/push)
```

## 2. Strip harness packages

The harness (`packages/ai` and `packages/agent`) lives in keel. hull only ships the features:

```bash
cd ~/keel-workspace/hull

# Remove harness packages — they're in keel now
rm -rf packages/ai packages/agent

# Verify only features remain
ls packages/
# Should show: coding-agent  tui  web-ui
```

## 3. Rewire imports to point at keel

Feature packages currently import from `packages/ai` and `packages/agent`. These need to point at keel's harness.

### Find affected imports

```bash
grep -rn "packages/ai\|packages/agent" packages/ --include="*.ts" | head -30
```

### Strategy

Keel's packages are still `@mariozechner/pi-ai` and `@mariozechner/pi-agent-core`.
Hull's feature packages import those same names. **Do not rename imports now** — it breaks every upstream cherry-pick. Resolve them at build time instead.

**Option A — tsconfig paths (recommended, do this now):**

Update `tsconfig.base.json` to add path aliases:

```json
"compilerOptions": {
  "paths": {
    "@mariozechner/pi-ai": ["../keel/packages/ai/src"],
    "@mariozechner/pi-agent-core": ["../keel/packages/agent/src"]
  }
}
```

This keeps import strings identical to upstream, so `hull-sync` cherry-picks apply cleanly. No `package.json` changes needed.

**Why not `file:` dependencies:** `npm publish` snapshots the entire referenced directory into the tarball. Consumers get a stale copy, not a live dependency. Local paths also break for anyone who doesn't have keel at the exact same filesystem location.

**Option B — scope rename + `npm link` (future only, when publishing independently):**

Only when hull and keel are ready to publish under `@devexcelsior/`:

```bash
# One-time bulk rename in source
sed -i 's/@mariozechner\/pi-ai/@devexcelsior\/keel-ai/g' packages/*/src/**/*.ts
sed -i 's/@mariozechner\/pi-agent-core/@devexcelsior\/keel-agent/g' packages/*/src/**/*.ts
```

Or use `npm link` / `link:` for local dev — symlinks don't bundle on publish.

This is a hard-fork decision. Once renamed, upstream cherry-picks that touch imports will conflict.

### Verify rewiring

```bash
# After rewiring, run typecheck
npx tsc --noEmit 2>&1 | head -20

# Should have zero errors related to missing ai/agent imports
```

## 4. Create sync-upstream.sh

This is the core of hull — the pipeline that keeps features current with upstream pi-mono:

```bash
mkdir -p scripts

cat > scripts/sync-upstream.sh << 'SYNCSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# sync-upstream — cherry-pick upstream pi-mono commits touching feature packages
# Run from hull/ root.
# Usage: ./scripts/sync-upstream.sh

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"

if ! git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  echo "Add upstream: git remote add upstream https://github.com/badlogic/pi-mono.git"
  exit 1
fi

git fetch "$UPSTREAM_REMOTE"

LAST_SYNC=$(git rev-parse refs/heads/sync-marker 2>/dev/null || git merge-base HEAD "$UPSTREAM_REMOTE/main")

COMMITS=$(git log --reverse --format="%H" "$LAST_SYNC..$UPSTREAM_REMOTE/main" 2>/dev/null || echo "")

if [[ -z "$COMMITS" ]]; then
  echo "Up to date."
  exit 0
fi

# Feature packages — everything except ai/agent (those live in keel)
FEATURE_PKGS=("packages/coding-agent" "packages/tui" "packages/web-ui")
APPLIED=0
SKIPPED=0
MANUAL=()

for commit in $COMMITS; do
  FILES=$(git diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null || echo "")
  MSG=$(git log --format="%s" -1 "$commit" 2>/dev/null)

  TOUCHES_FEATURES=false
  TOUCHES_HARNESS=false

  for f in $FILES; do
    matched=false
    for pkg in "${FEATURE_PKGS[@]}"; do
      [[ "$f" == "$pkg"/* || "$f" == "$pkg" ]] && matched=true
    done
    if $matched; then
      TOUCHES_FEATURES=true
    else
      TOUCHES_HARNESS=true
    fi
  done

  if $TOUCHES_FEATURES && ! $TOUCHES_HARNESS; then
    echo "[$commit] APPLY : $MSG"
    git cherry-pick "$commit" --strategy-option=theirs 2>&1 || {
      echo "CONFLICT — aborting cherry-pick"
      MANUAL+=("CONFLICT:$commit:$MSG")
      git cherry-pick --abort 2>/dev/null || true
    }
    ((APPLIED++)) || true
  elif $TOUCHES_FEATURES && $TOUCHES_HARNESS; then
    echo "[$commit] MANUAL: $MSG (touches features + harness)"
    MANUAL+=("CROSS:$commit:$MSG")
  else
    echo "[$commit] SKIP  : $MSG (harness-only — belongs in keel)"
    ((SKIPPED++)) || true
  fi
done

git branch -f sync-marker "$UPSTREAM_REMOTE/main"

echo ""
echo "Applied: $APPLIED  Skipped: $SKIPPED  Manual: ${#MANUAL[@]}"
for entry in "${MANUAL[@]}"; do
  echo "  $entry"
done
SYNCSCRIPT

chmod +x scripts/sync-upstream.sh
```

## 5. Write README

```bash
cat > README.md << 'EOF'
# hull

The full pi experience. Built on the harness that can't be removed.

## What

hull is the features layer of pi — TUI, web UI, plugins, and CLI. It tracks upstream [pi-mono](https://github.com/badlogic/pi-mono) and runs on top of [keel](https://github.com/devexcelsior/keel), the MPL-2.0 harness.

## Architecture

```
helm (MIT)         ← methodology, prompts, orchestration
hull (MIT)         ← this repo — TUI, web UI, plugins, CLI
keel (MPL-2.0)     ← agent engine + LLM API — can't be removed
```

## How it works

hull is a build pipeline, not a static fork:

```
pi-mono (upstream) ──pull──→ hull ──rewrite imports──→ features on keel
```

- Clones upstream pi-mono
- Strips harness packages (they live in keel)
- Rewires imports so features point at keel's harness API
- Syncs daily via `scripts/sync-upstream.sh`

If pi-mono ever changes its license, the sync script stops pulling. hull becomes the community upstream for features from the last MIT commit.

## Quick start

```bash
# Clone hull alongside keel
git clone https://github.com/devexcelsior/keel.git
git clone https://github.com/devexcelsior/hull.git

# Build the harness
cd keel && npm install && npm run build && cd ..

# Build features against the harness
cd hull && npm install && npm run build && cd ..
```

## Staying current

```bash
./scripts/sync-upstream.sh
```

Cherry-picks upstream pi-mono commits that touch feature packages (coding-agent, tui, web-ui). Harness-only commits are skipped — those belong in keel.

## License

MIT. See [LICENSE](LICENSE).
EOF
```

## 6. LICENSE (MIT)

```bash
# Copy the original MIT license from upstream
curl -sL https://raw.githubusercontent.com/badlogic/pi-mono/main/LICENSE -o LICENSE

# Prepend hull header
sed -i '1s|^|hull — https://github.com/devexcelsior/hull\nMIT License (original pi-mono license)\n\n|' LICENSE
```

## 7. Build and verify

```bash
npm install
npm run build 2>&1

# If build fails, fix import paths (step 3) and retry
npm test 2>&1 || echo "Tests not fully configured — expected"
```

## 8. Commit and push

```bash
git add -A
git status

git commit -m "initialize: hull — MIT feature pipeline on keel harness

Stripped harness packages (ai, agent — live in keel).
Rewired feature imports to keel harness API.
Added sync-upstream.sh for daily upstream tracking.

MIT licensed. Tracks pi-mono upstream. Built on the harness that can't be removed."

git push origin main
```

## 9. Update GitHub repo settings

Set description: `The full pi experience. Built on the harness that can't be removed.`

---

## Notes for the agent executing this

1. If `devexcelsior/hull` doesn't exist on GitHub, stop and tell the user to create it first.
2. Every step is a bash command. Run them, don't simulate.
3. The import rewiring (step 3) is the highest-risk step. Test with `npx tsc --noEmit` after each approach.
4. Use tsconfig paths (Option A) for now — it preserves upstream import names, enables clean cherry-picks, and avoids `file:` dependency footguns. Scope rename is a future hard-fork decision.
5. Do not modify feature logic. This is structural + import path changes only.
6. When pi-mono eventually closes, hull's sync script stops pulling. That's the design. The last MIT-synced commit becomes the community baseline.

---

## Remaining for tomorrow

| # | Slug | Status | What |
|---|---|---|---|
| 5 | `hull-readme` | ⏳ Not started | Write README.md with architecture diagram, clone/build/sync instructions, MIT license header. Overwrite upstream README. |
| 6 | `hull-build` | ⏳ Deferred | `npm install`, `npm run build`, `npm run test --workspaces --if-present`. Requires: (a) keel packages linked or built, (b) `tsconfig.base.json` paths verified in package builds, (c) `@mariozechner/pi-coding-agent` dependency in root package.json may need local override. |

### Blockers for hull-build

1. **keel must be linked or built locally** — `npm link` the ai and agent packages, or add them as `file:` deps temporarily for the build.
2. **`tsconfig.base.json` paths** — just added `@mariozechner/pi-ai` → `../keel/packages/ai/src`. Verify `packages/coding-agent/tsconfig.build.json` picks these up on `npm run build`.
3. **Root package.json dependency** — `"@mariozechner/pi-coding-agent": "^0.30.2"` in `dependencies` may resolve from npm instead of local workspace. Check if this causes version skew.

### Next command

```bash
cd /home/devex/Projects/hull
/home/devex/.pi/agent/bin/pi-orchestrate hull-readme "Write README.md with architecture diagram showing hull depends on keel at /home/devex/Projects/keel, clone/build/sync instructions, MIT license header. Overwrite upstream README."
```