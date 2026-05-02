# Roadmap: hull-clone

Add upstream remote to existing `devexcelsior/hull` repo and verify all remotes.

## Context

The repository at `devexcelsior/hull` already exists locally with `origin` correctly set to `https://github.com/devexcelsior/hull.git` (confirmed: `README.md` at repo root, single commit `487483c initial`). The missing piece is the upstream remote pointing to the source repository `badlogic/pi-mono` so this fork can track upstream changes.

## Decisions

### Decision 1: Upstream remote URL format — HTTPS over SSH

**Decision**: Add upstream remote using HTTPS URL `https://github.com/badlogic/pi-mono.git`.

**Constraints**: The existing `origin` remote already uses HTTPS (`https://github.com/devexcelsior/hull.git`). Using the same transport protocol for `upstream` avoids mixed-credential friction in CI and local environments that lack SSH keys configured.

**Second-order effects**: None for runtime code — this is a repository metadata change only. Future `git fetch upstream` operations will use HTTPS credentials (or tokens) already configured for `origin`.

**Failure modes**: Using SSH (`git@github.com:badlogic/pi-mono.git`) would fail in environments without an SSH key configured, producing a cryptic `Permission denied (publickey)` on first `git fetch upstream`. The deceptively obvious choice of "use SSH because it's the secure default" is wrong here because the repo's existing `origin` is HTTPS; consistency across remotes reduces credential-configuration surface.

**Alternatives considered**:
- **SSH (`git@github.com:badlogic/pi-mono.git`)**: Rejected. No evidence that SSH keys are configured in this environment. Mixed SSH/HTTPS remotes force the user to maintain two credential mechanisms.
- **GitHub CLI remote (`gh repo sync` workflow)**: Rejected. Introduces a tool dependency (`gh`) not mentioned in the topic. The task is explicitly about remotes, not CLI workflows.

**Self-consistency check**: No earlier decisions in this plan. N/A.

### Decision 2: Include a `git fetch upstream --dry-run` in verification

**Decision**: After adding the remote, run `git fetch upstream --dry-run` to verify the remote is reachable without mutating the local branch state.

**Constraints**: The repo currently has no upstream remote (verified as a pre-condition in Step 1). The verification must prove the remote points to a valid, reachable repository.

**Second-order effects**: None — dry-run produces no refs or objects.

**Failure modes**: Skipping reachability verification and relying only on `git remote -v` would allow a typo in the URL to go undetected. The deceptively obvious answer "`git remote -v` is sufficient verification" is wrong because it only checks the *configured* string, not whether that string resolves to a real repository. Additionally, `--dry-run` may fail for network-level reasons (DNS failure, TLS handshake error, GitHub rate-limit 403/429) even when the URL is correct; the failure mode here is conflating "URL typo" with "temporary network unreachability." The deceptively obvious answer "a failing `--dry-run` means the URL is wrong" is wrong because it ignores transient infrastructure failures.

**Alternatives considered**:
- **`git fetch upstream` (non-dry)**: Rejected. Would pull refs and objects into `refs/remotes/upstream/*`, polluting the local repo with upstream branches not requested by the user.
- **No reachability check**: Rejected. Violates the topic's explicit "verify remotes" requirement.

**Self-consistency check**: Consistent with Decision 1 (HTTPS) — `git fetch` over HTTPS with a valid URL will either succeed or prompt for credentials, providing immediate signal on URL correctness.

## Cross-cutting concerns

| Concern | Status | Rationale |
|---|---|---|
| Testing strategy | **User-verifiable bash checks** | No runtime code. Verification is performed by the user (or agent) via `git remote -v`, `git remote get-url`, and `git fetch --dry-run`. Acceptance criteria are framed as user-observable outcomes: "user can run `git fetch upstream` without error" rather than internal implementation details. |
| Accessibility | **N/A** | No UI. |
| Error handling | **Pre-condition guards + explicit abort** | Step 1 aborts before mutating remotes if any pre-condition fails (wrong CWD, wrong origin URL, or upstream already exists). `git remote add` and `git fetch` surface their own error messages; no custom fallback is required beyond the pre-condition guards. |
| Observability | **N/A** | No runtime services. |
| Deployment | **N/A** | No build artifacts. |
| Security | **N/A** | No secrets, auth, or CSP. The upstream URL is a public GitHub repository. |
| Performance budgets | **N/A** | No runtime code. |

## Discipline-axis self-check

1. **Deferred decisions**: None. The URL format (HTTPS), the exact upstream slug (`badlogic/pi-mono`), and the verification strategy (`--dry-run`) are all pinned with one-sentence reasons.
2. **Unjustified specifics**: None. HTTPS is justified by existing `origin` protocol consistency. `--dry-run` is justified by avoiding local branch pollution.
3. **Circular rejection reasoning**: None. Alternatives rejected on independent grounds (tool dependency, credential friction, local pollution).
4. **Missing cross-cutting concerns**: None — all seven concerns are either resolved or explicitly marked N/A with rationale.

## Pre-conditions

The following must hold before executing Step 1. They are not deliverables of this feature; they are existing state that the step assumes.

1. The current working directory is the root of the `devexcelsior/hull` repository (verified by `git rev-parse --show-toplevel`).
2. `origin` is already configured and points to `https://github.com/devexcelsior/hull.git` (verified by `git remote get-url origin`).
3. No remote named `upstream` exists yet (verified by `git remote get-url upstream` exiting non-zero).

## Steps

Given the minimal surface area, this feature decomposes to a single step.

### Step 1: Add upstream remote and verify

1. Verify CWD is the repo root (`git rev-parse --show-toplevel` must match the expected path).
2. Verify `origin` URL (`git remote get-url origin` must emit `https://github.com/devexcelsior/hull.git`).
3. Verify no `upstream` remote exists (`git remote get-url upstream` must exit non-zero).
4. Add upstream remote `https://github.com/badlogic/pi-mono.git`.
5. Verify with `git remote -v` (both `origin` and `upstream` must appear, each with separate `(fetch)` and `(push)` lines).
6. Verify reachability of both remotes with `git fetch origin --dry-run` and `git fetch upstream --dry-run`.

> **Error handling**: If any pre-condition fails, the step aborts before mutating remotes. `git remote add` and `git fetch` surface their own errors; no custom fallback is needed beyond the pre-condition guards above. Network-level failures (DNS, TLS, GitHub rate-limit 403/429) may cause `--dry-run` to fail even when the URL is correct; in that case the URL is still considered correctly configured, but reachability is temporarily unavailable.

## Acceptance criteria

1. Pre-condition: `git rev-parse --show-toplevel` confirms execution from the repo root.
2. Pre-condition: `git remote get-url origin` returns `https://github.com/devexcelsior/hull.git`.
3. Pre-condition: `git remote get-url upstream` exits non-zero (no upstream yet).
4. `git remote -v` shows two lines for `origin`: one with `(fetch)` and one with `(push)`, both pointing to `https://github.com/devexcelsior/hull.git`.
5. `git remote -v` shows two lines for `upstream`: one with `(fetch)` and one with `(push)`, both pointing to `https://github.com/badlogic/pi-mono.git`.
6. `git fetch origin --dry-run` exits 0 (origin reachable).
7. `git fetch upstream --dry-run` exits 0 (upstream reachable).

---

## Responses to critiques

### pm-requirements

| # | Point | Response |
|---|---|---|
| 1 | Title/goal vs. actual scope misalignment: title promises clone + set-origin, plan only adds upstream | **Incorporated**: narrowed title to "Add upstream remote to existing `devexcelsior/hull` repo and verify all remotes" (line 1) and added Pre-conditions section (lines 70–76) to verify existing clone/origin state. |
| 2 | Missing pre-condition / existing-state verification for origin | **Incorporated**: added Pre-conditions section (lines 70–76) and Acceptance criterion 2 (line 83) that `git remote get-url origin` returns the expected URL before any mutation. |
| 3 | No acceptance criterion for origin reachability | **Incorporated**: added Acceptance criterion 6 (line 88) requiring `git fetch origin --dry-run` exits 0. |
| 4 | No error-handling acceptance criterion for upstream already existing | **Incorporated**: added Pre-condition 3 (line 76) and Step 1.3 (line 82) verifying `git remote get-url upstream` exits non-zero before `git remote add`. |
| 5 | Ambiguous "(fetch and push)" phrasing in acceptance criteria | **Incorporated**: rewrote Acceptance criteria 4–5 (lines 86–87) to explicitly require two lines per remote, one with `(fetch)` and one with `(push)`. |

### senior-engineer-risk

| # | Point | Response |
|---|---|---|
| 1 | Idempotency gap: `git remote add upstream` fails if upstream already exists | **Incorporated**: added Pre-condition 3 (line 76) and Step 1.3 (line 82) that verify `git remote get-url upstream` exits non-zero before attempting `git remote add`. |
| 2 | Working directory assumption: step commands assume repo root CWD | **Incorporated**: added Pre-condition 1 (line 74) and Step 1.1 (line 80) that verify CWD via `git rev-parse --show-toplevel`. |
| 3 | Failure mode narrowness in Decision 2: omits network-level failures | **Incorporated**: expanded Decision 2 Failure modes (lines 58–61) to name DNS, TLS, and GitHub rate-limit failures that can cause `--dry-run` to fail despite a correct URL. |
| 4 | Origin verification gap: plan never verifies origin before mutating remotes | **Incorporated**: added Pre-condition 2 (line 75) and Step 1.2 (line 81) that verify `origin` URL via `git remote get-url origin` before any mutation. |

### Discipline-axis findings (cross-critique)

| Axis | Finding | Response |
|---|---|---|
| Error handling | Cross-cutting concerns table marked "Default" with thin rationale | **Resolved**: changed Error handling status to "Pre-condition guards + explicit abort" with explicit rationale (line 66). |
| Testing strategy | Cross-cutting concerns table marked "N/A" with thin rationale | **Resolved**: changed Testing strategy status to "User-verifiable bash checks" with explicit rationale (line 65). |

---
**Shipped**: 2026-05-01 | Branch: feature/hull-clone | ADR: 0001

`produced-adrs: [0001]`

---
**✅ Revised plan written — response table appended — ready for /decompose**

| Phase | Command | Thinking |
|---|---|---|
| **Now** | `/decompose` | **medium** — Shift+Tab down from high |
| Then | `/preflight` (step 1) | **minimal** |
| Then | `/implement` | **medium** |
| Then | `/verify` | **minimal** |
