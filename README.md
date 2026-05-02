# hull

The full pi experience. Built on the open harness.

## What

hull is the features layer of pi — TUI, web UI, plugins, and CLI. It tracks upstream [pi-mono](https://github.com/badlogic/pi-mono) and runs on top of [keel](https://github.com/devexcelsior/keel), the MPL-2.0 harness that keeps the core open.

## Architecture

```
helm (MIT)         ← methodology, prompts, orchestration
hull (MIT)         ← this repo — TUI, web UI, plugins, CLI
keel (MPL-2.0)     ← agent engine + LLM API
```

## How it works

hull is a build pipeline, not a static fork:

```
pi-mono (upstream) ──pull──→ hull ──rewrite imports──→ features on keel
```

- Tracks upstream pi-mono
- Stripped harness packages (ai, agent) — those live in keel
- Imports rewired via tsconfig paths to keel's harness API
- Syncs daily via `scripts/sync-upstream.sh`

If pi-mono ever changes its license, the sync script stops pulling. hull becomes the community upstream for features from the last MIT commit.

## Packages

| Package | Description |
|---------|-------------|
| **coding-agent** | Interactive coding agent CLI |
| **tui** | Terminal UI library with differential rendering |
| **web-ui** | Web components for AI chat interfaces |

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
