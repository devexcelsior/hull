# Calibration trace: hull-clone

## Step 1 — add-upstream-remote

**Verified**: 2026-05-01 21:12
**Phases run**: /implement, /verify
**Verdict**: PASS

### Anti-flattery scan

1. **Implementation drift**: No drift. The implementation executed the exact sequence from the step doc's `## Implementation sketch` section: pre-condition checks (repo root via `git rev-parse --show-toplevel`, origin URL via `git remote get-url origin`, upstream absence via `git remote get-url upstream` exiting non-zero), followed by `git remote add upstream https://github.com/badlogic/pi-mono.git`, then verification via `git remote -v` and `git fetch --dry-run`. The verify output confirms verbatim execution of each command listed in the sketch.

2. **Verify-gate evidence**: All gates cited evidence. Constraint gate rows 1, 2, and 4 quote explicit command output (e.g., "`git remote get-url origin` returns `https://github.com/devexcelsior/hull.git`"). Row 3 is explicitly marked "N/A in verify — pre-condition was satisfied before implementation" rather than rubber-stamped. Invariant gate cites `git config --local --get` and `git diff --name-only` with quoted results. Each AC checkbox is paired with a verification command table showing output and exit code. No bare "Yes" or "verified" claims without citations.

3. **Phase budget**: Extremely lightweight — expected for a pure git configuration step. Implementation was a single `git remote add` command. Verify ran 8 shell commands. No preflight was needed (the step touched no source files, used no new APIs, and created no new files — preflight skip justified per §6). Total tool calls for implement+verify were minimal, matching the trivial complexity of the step.

4. **Cross-step pattern**: N/A — this is a single-step feature (Total steps: 1). No prior or subsequent steps for pattern comparison.

5. **Surprise**: `git fetch upstream --dry-run` on a never-before-fetched remote produced verbose output listing all upstream branches and tags (~150 lines), despite being a dry run. The verify output correctly noted this explicitly ("exit 0, lists branches/tags from upstream") and still marked Pass. This could surprise future reviewers who expect `--dry-run` to be silent; it is normal git behavior for first fetch but worth documenting in calibration notes for similar steps.

6. **Test quality**: No tests added — step is N/A. The step doc's `## Mechanical constraint checks` section states: "No defensive-code constraints — pure git metadata change with no executable code, no runtime APIs, no error paths." There is no `## Test mapping` section; per §2 rule 8, steps modifying only configuration may omit test mapping with explicit justification. The mechanical checks section's justification arguably serves this purpose, though it is not in the dedicated `## Test mapping` format.

### Findings (classified)

- F1 [portable]: `git fetch --dry-run` against a never-fetched remote produces large branch/tag listing output. Future verify templates for first-time upstream fetches should expect and document this verbosity to avoid false alarm during review.
- F2 [portable]: The verify output correctly noted constraint #3 as "N/A in verify" because it was a pre-condition verified during implementation, not post-hoc. This is honest gate-keeping and should be encouraged as a pattern over synthetic post-hoc checks that mutate state.
- F3 [harness-specific]: The `/verify` phase correctly persisted its full output to `docs/calibration/verify-hull-clone-step-1.md`, satisfying the output-persistence rule from §5 gate 6.
- F4 [?]: Step doc omitted a dedicated `## Test mapping` section entirely. While justified by the pure-config nature of the step, the omission lacked the explicit one-line justification format prescribed by §2 rule 8 ("No runtime code — test mapping N/A"). This is a minor template-form deviation with no functional impact.
