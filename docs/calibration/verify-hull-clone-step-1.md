# Verification: hull-clone / step-1-add-upstream-remote

## Mechanical constraint checks

Step doc explicitly states: "No defensive-code constraints — pure git metadata change with no executable code, no runtime APIs, no error paths."

No mechanical checks declared; no gap — justification is present in the step doc.

## Constraint gate

| # | Constraint (quoted from step doc) | Satisfied? | Evidence |
|---|---|---|---|
| 1 | "Execution must happen from the repository root" | Yes | `git rev-parse --show-toplevel` returns `/home/devex/Projects/hull-hull-clone` |
| 2 | "`origin` must already point to `https://github.com/devexcelsior/hull.git` before any mutation" | Yes | `git remote get-url origin` returns `https://github.com/devexcelsior/hull.git` |
| 3 | "No remote named `upstream` must exist before attempting `git remote add`" | N/A in verify — pre-condition was satisfied before implementation |
| 4 | "The upstream URL must use HTTPS to match the existing `origin` protocol" | Yes | `git remote get-url upstream` returns `https://github.com/badlogic/pi-mono.git` |

## Invariant gate

| # | Invariant | How verified | Result |
|---|---|---|---|
| 1 | `origin` remote configuration unchanged | Re-read `git config --local --get remote.origin.url` — still `https://github.com/devexcelsior/hull.git` | Preserved |
| 2 | No local branches, tags, or working-tree files modified | `git diff --name-only` returns empty; `git status --short` shows no modified tracked files | Preserved |
| 3 | `.git/config` only gained `[remote "upstream"]` | `git config --local --get remote.upstream.url` returns the new URL; origin URL unchanged; no other config drift detected | Preserved |

## Verification commands

| # | Command | Output / Exit | Verdict |
|---|---|---|---|
| AC 1 | `git rev-parse --show-toplevel` | `/home/devex/Projects/hull-hull-clone` (exit 0) | Pass |
| AC 2 | `git remote get-url origin` | `https://github.com/devexcelsior/hull.git` (exit 0) | Pass |
| AC 3 | `git remote get-url upstream` | `https://github.com/badlogic/pi-mono.git` (exit 0) | Pass |
| AC 4a | `git remote -v \| grep origin fetch` | `origin	https://github.com/devexcelsior/hull.git (fetch)` (exit 0) | Pass |
| AC 4b | `git remote -v \| grep origin push` | `origin	https://github.com/devexcelsior/hull.git (push)` (exit 0) | Pass |
| AC 5a | `git remote -v \| grep upstream fetch` | `upstream	https://github.com/badlogic/pi-mono.git (fetch)` (exit 0) | Pass |
| AC 5b | `git remote -v \| grep upstream push` | `upstream	https://github.com/badlogic/pi-mono.git (push)` (exit 0) | Pass |
| AC 6 | `git fetch origin --dry-run` | exit 0 | Pass |
| AC 7 | `git fetch upstream --dry-run` | exit 0, lists branches/tags from upstream | Pass |

## Acceptance criteria

- [x] AC 1: `git rev-parse --show-toplevel` confirms execution from the repo root.
- [x] AC 2: `git remote get-url origin` returns `https://github.com/devexcelsior/hull.git`.
- [x] AC 3: `git remote get-url upstream` returns `https://github.com/badlogic/pi-mono.git`.
- [x] AC 4: `git remote -v` shows two lines for `origin` with fetch and push.
- [x] AC 5: `git remote -v` shows two lines for `upstream` with fetch and push.
- [x] AC 6: `git fetch origin --dry-run` exits 0.
- [x] AC 7: `git fetch upstream --dry-run` exits 0.

**Result: PASS**
