# ADR 0001: Add upstream remote to hull fork

## Status

**Accepted** — 2026-05-01

## Context

The `devexcelsior/hull` repository is a fork of `badlogic/pi-mono`. The `origin` remote was already correctly configured to the fork's own GitHub URL (`https://github.com/devexcelsior/hull.git`), but there was no `upstream` remote pointing back to the source repository. Without an upstream remote, the fork could not track changes from the original repository via `git fetch upstream`.

## Decision drivers

1. **Enable upstream tracking** — The fork needs a way to pull changes from the original repository.
2. **Credential consistency** — The existing `origin` remote uses HTTPS; mixing transport protocols across remotes increases credential-configuration surface.
3. **Non-destructive verification** — Verifying that a remote URL is correct should not mutate local branch state or pull refs into the local namespace.

## Options considered

### Option A: SSH URL (`git@github.com:badlogic/pi-mono.git`)

Rejected. There was no evidence that SSH keys were configured in the target environment. Mixing SSH for `upstream` with HTTPS for `origin` would force maintaining two credential mechanisms. The deceptively obvious choice "use SSH because it's the secure default" was wrong because consistency with the existing `origin` protocol reduces friction more than protocol purity helps.

### Option B: GitHub CLI (`gh repo sync`)

Rejected. This introduces a tool dependency (`gh`) not already required by the repository or its workflows. The task scope was remotes, not CLI-based sync workflows.

### Option C: No reachability verification

Rejected. `git remote -v` only validates the *configured string*, not whether that string resolves to a real, reachable repository. A typo in the URL would go undetected until a future fetch attempt failed.

## Chosen option

Add the `upstream` remote using the HTTPS URL `https://github.com/badlogic/pi-mono.git`, matching the existing `origin` transport protocol. After adding the remote, verify reachability with `git fetch upstream --dry-run` — this confirms the URL resolves to a real repository without pulling refs or objects into the local namespace.

## Consequences

### Positive

- The fork can now track upstream changes via `git fetch upstream`.
- Consistent HTTPS transport across both remotes means existing tokens/credentials work for both `origin` and `upstream` operations.
- `--dry-run` verification confirms reachability without side effects — no local branches, tags, or refs are modified.

### Negative

- HTTPS requires token or credential management; environments that prefer SSH key-based auth will still need manual credential configuration.
- Temporary network failures (DNS, TLS, GitHub rate-limit 403/429) during `--dry-run` can be mistaken for URL misconfiguration.

### To watch

- If SSH keys are configured later, the user may want to switch both `origin` and `upstream` to SSH for consistency.
- If `badlogic/pi-mono` is renamed or transferred, the `upstream` URL will need updating.

## Validation

- `git remote -v` shows two lines for `upstream`, one with `(fetch)` and one with `(push)`, both pointing to `https://github.com/badlogic/pi-mono.git`.
- `git fetch upstream --dry-run` exits 0, confirming the remote is reachable.

## Supersedes

None.

## Distilled from

`docs/roadmap/hull-clone/hull-clone.md`
