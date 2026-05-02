# Step 1: Add upstream remote and verify

## Context

The repository at `devexcelsior/hull` is a fork of `badlogic/pi-mono`. The `origin` remote is already correctly configured to `https://github.com/devexcelsior/hull.git`. The missing piece is the `upstream` remote that points back to the source repository, enabling the fork to track upstream changes via `git fetch upstream`.

## Decision

Add the `upstream` remote using the HTTPS URL `https://github.com/badlogic/pi-mono.git` and verify both remotes are reachable with `git fetch --dry-run`.

## Constraints

1. Execution must happen from the repository root (`git rev-parse --show-toplevel` must match the expected path).
2. `origin` must already point to `https://github.com/devexcelsior/hull.git` before any mutation.
3. No remote named `upstream` must exist before attempting `git remote add`.
4. The upstream URL must use HTTPS to match the existing `origin` protocol, avoiding mixed-credential friction.

## Second-order effects

None. This is a pure git configuration change. No source files, build artifacts, or runtime behavior are affected.

## Failure modes

1. **Wrong working directory**: If executed outside the repo root, `git remote add` would modify the wrong repository or fail. Mitigation: pre-condition check via `git rev-parse --show-toplevel`.
2. **Upstream already exists**: `git remote add upstream` would fail with "fatal: remote upstream already exists." Mitigation: pre-condition check via `git remote get-url upstream` (must exit non-zero).
3. **Typo in upstream URL**: `git remote -v` would show a malformed URL but not surface the error until a fetch attempt. Mitigation: `git fetch upstream --dry-run` verifies reachability immediately.
4. **Network-level fetch failure**: DNS, TLS, or GitHub rate-limit errors can cause `--dry-run` to fail even with a correct URL. This does not indicate misconfiguration, only temporary unreachability.

## Alternatives considered

1. **SSH URL (`git@github.com:badlogic/pi-mono.git`)**: Rejected. The existing `origin` uses HTTPS; mixing protocols forces maintaining two credential mechanisms. No evidence SSH keys are configured in this environment.
2. **GitHub CLI (`gh repo sync`)**: Rejected. Introduces a tool dependency (`gh`) not mentioned in the topic. The task scope is remotes, not CLI workflows.
3. **No reachability verification**: Rejected. Violates the explicit "verify remotes" requirement. `git remote -v` only checks the configured string, not whether it resolves to a real repository.

## Self-consistency check

This is the only step in the plan. No contradictions with earlier decisions. The HTTPS choice (Decision 1) and `--dry-run` verification (Decision 2) are orthogonal — one concerns transport protocol, the other concerns validation strategy.

## Files touched

No repository source files are modified. Only git remote configuration (stored in `.git/config` within the main git directory) is mutated.

## API / function signatures

No functions or APIs are called. This step uses the `git` CLI directly:
- `git rev-parse --show-toplevel`
- `git remote get-url <name>`
- `git remote add <name> <url>`
- `git remote -v`
- `git fetch <remote> --dry-run`

## Mechanical constraint checks

No defensive-code constraints — pure git metadata change with no executable code, no runtime APIs, no error paths.

## Implementation sketch

Run the following commands in order. Abort immediately if any pre-condition check fails.

```bash
# Pre-condition 1: verify CWD is the repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
# Expected: /home/devex/Projects/hull-hull-clone (or the worktree path)

# Pre-condition 2: verify origin URL
ORIGIN_URL=$(git remote get-url origin)
# Expected: https://github.com/devexcelsior/hull.git

# Pre-condition 3: verify upstream does not exist yet
git remote get-url upstream
# Expected: exit code non-zero (error: No such remote 'upstream')

# Add upstream remote
git remote add upstream https://github.com/badlogic/pi-mono.git

# Verification 1: list all remotes
git remote -v
# Expected output shows:
# origin    https://github.com/devexcelsior/hull.git (fetch)
# origin    https://github.com/devexcelsior/hull.git (push)
# upstream  https://github.com/badlogic/pi-mono.git (fetch)
# upstream  https://github.com/badlogic/pi-mono.git (push)

# Verification 2: dry-run fetch both remotes
git fetch origin --dry-run
# Expected: exit 0
git fetch upstream --dry-run
# Expected: exit 0
```

## Verification commands

After executing the implementation sketch, run these exact verification commands and report exit codes:

```bash
# AC 1: CWD is repo root
git rev-parse --show-toplevel

# AC 2: origin URL is correct
git remote get-url origin

# AC 3: upstream URL is correct
git remote get-url upstream

# AC 4: git remote -v shows origin with fetch and push
git remote -v | grep -E '^origin\s+https://github\.com/devexcelsior/hull\.git \(fetch\)$'
git remote -v | grep -E '^origin\s+https://github\.com/devexcelsior/hull\.git \(push\)$'

# AC 5: git remote -v shows upstream with fetch and push
git remote -v | grep -E '^upstream\s+https://github\.com/badlogic/pi-mono\.git \(fetch\)$'
git remote -v | grep -E '^upstream\s+https://github\.com/badlogic/pi-mono\.git \(push\)$'

# AC 6: origin is reachable
git fetch origin --dry-run

# AC 7: upstream is reachable
git fetch upstream --dry-run
```

## Invariants to preserve

1. `origin` remote configuration must not change — its URL, fetch/push lines, or any associated refspecs must remain exactly as they were before this step.
2. No local branches, tags, or working-tree files must be modified.
3. The `.git/config` file in the main repository must only gain the new `[remote "upstream"]` section; no other sections may be altered.

## Acceptance criteria

1. `git rev-parse --show-toplevel` confirms execution from the repo root.
2. `git remote get-url origin` returns `https://github.com/devexcelsior/hull.git`.
3. `git remote get-url upstream` returns `https://github.com/badlogic/pi-mono.git`.
4. `git remote -v` shows two lines for `origin`: one with `(fetch)` and one with `(push)`, both pointing to `https://github.com/devexcelsior/hull.git`.
5. `git remote -v` shows two lines for `upstream`: one with `(fetch)` and one with `(push)`, both pointing to `https://github.com/badlogic/pi-mono.git`.
6. `git fetch origin --dry-run` exits 0 (origin reachable).
7. `git fetch upstream --dry-run` exits 0 (upstream reachable).
