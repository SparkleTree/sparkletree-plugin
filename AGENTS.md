# SparkleTree plugin: orientation for agents

You are in the SparkleTree plugin repository. It packages skills, two agents, three hooks and one remote MCP server declaration for Claude Code, Codex, ChatGPT, Gemini CLI, Cursor and any MCP client. The server itself is not in this repo; it runs at `https://app.sparkletree.io/api/mcp` and is owned by the SparkleTree monorepo.

## If you are here to use SparkleTree

Read `skills/sparkletree/SKILL.md` first. It carries the rules that every other skill assumes: read `mosaic://capabilities`, read before write, confirm before publish, deploy, delete or credit spend. `skills/sparkletree/references/tools.md` is the tool table.

## If you are here to change the plugin

Layout (only `plugin.json` and `marketplace.json` live in `.claude-plugin/`; everything else sits at the root):

- `.claude-plugin/plugin.json`: manifest. `name` is `sparkletree` and must not change (it namespaces skills and agents, and scopes MCP tool names to `mcp__plugin_sparkletree_sparkletree__<tool>`).
- `.claude-plugin/marketplace.json`: one-plugin marketplace with `source: "./"`.
- `.codex-plugin/plugin.json`: Codex manifest. Same identity and version as `.claude-plugin/plugin.json`, plus the `interface` block the OpenAI portal reads (display name, category, links, `assets/icon.webp`). Paths are relative and start with `./`; `skills`, `mcpServers` and `hooks` point at the same files Claude Code uses.
- `.mcp.json`: the remote server. Loads as `plugin:sparkletree:sparkletree`, so its tools are `mcp__plugin_sparkletree_sparkletree__<tool>`. When the user already has SparkleTree as a claude.ai connector for the same URL, Claude Code suppresses the plugin's copy as a duplicate (debug log: "Lazy dedup") and the tools appear under the connector's own server id (`mcp__<connector-id>__<tool>`).
- `skills/<name>/SKILL.md` plus `references/`: thirteen model-invocable skills and two user-invoked commands (`setup`, `launch`, both `disable-model-invocation: true`). Descriptions open with SparkleTree and the main use case, stay under 460 characters, and never rely on the description alone: when the host's skill listing overflows, only the name survives, so the name must say what the skill does. Bodies stay under 500 lines; long material goes in `references/`.
- `agents/`: `campaign-reviewer` and `analytics-digest`, both read-only via `disallowedTools` listing every write tool (including `upload_asset`) under both the plugin-scoped and the bare server name. A claude.ai connector's tool ids cannot be named there; the spend guard denies those inside the agents.
- `hooks/hooks.json`, `scripts/check-connector.sh`, `scripts/spend-guard.sh`, `scripts/job-watch.sh`: POSIX sh; `spend-guard.sh` parses with jq only and fails closed without it or on input it cannot read (every guarded call asks, is refused once in the modes without prompts, or is denied inside the read-only agents). `check-connector.sh` and `job-watch.sh` never use jq. The other files under `scripts/` are maintainer tooling (jq, git, curl): `bump-version.sh` moves a version, `ci-validate.sh` and `ci-check-bump.sh` are the push checks, `ci-tag.sh` tags on main, `ci-directory-branch.sh` rebuilds the `directory` branch from main through `directory-transform.sh` (tested by `test-directory-transform.sh`; see "Versions" in README.md), `build-openai-bundle.sh` builds the OpenAI zip, `test-hooks.sh` feeds hook payloads through the hook scripts with jq, with `SPARKLETREE_NO_JQ=1`, with jq hidden from PATH and without a SHA-256 tool; `test-ci-check-bump.sh` checks which changes need a bump.
  - `check-connector.sh` (SessionStart: startup, clear, compact) curls `https://app.sparkletree.io/api/health` (`SPARKLETREE_HEALTH_URL` overrides) with a two-second limit, adds one routing line to the context (`SPARKLETREE_SESSION_CONTEXT=off` drops it), is silent on success apart from that line, and always exits 0.
  - `spend-guard.sh` (PreToolUse) has the matcher `mcp__.*__(generate_campaign|render_video|video_commission|manage_campaigns|manage_products|manage_brand|manage_surfaces|upload_asset)$`, wide on the server segment on purpose: the same tools arrive as the plugin-scoped name, a hand-added `mcp__sparkletree__` server, or a claude.ai connector id, and the script keys on the tool-name suffix. The narrower `mcp__(plugin_sparkletree_)?sparkletree__(...)` form misses the connector case. No `query_*` tool is in the matcher: every one is a pure read. `check_component` and `match_templates` are `manage_campaigns` actions (they change no campaign data but use a daily allowance) and get `ask`. A `query_*` call that reaches the script anyway exits 0 silently before anything else. Inside the `campaign-reviewer` and `analytics-digest` agents every call that reaches the guard is denied. Otherwise it returns `ask` for credit spend, daily sandbox and model allowances, quota, live changes and deletes, and nothing for reads and drafts. In auto, bypassPermissions and dontAsk modes, where an `ask` never reaches the user, a credit-spending call is denied once and the identical call from 2 seconds to 15 minutes later passes once (markers under `${CLAUDE_PLUGIN_DATA}/confirm/`, named by a SHA-256 digest of the session id, the full `tool_name` and `jq -cS` of `tool_input`, and consumed with `mv` so racing calls cannot share a yes); other guarded calls pass. The tool name comes from the top-level `tool_name` only. `SPARKLETREE_SPEND_GUARD=prompt-only` or `off` changes this. It cannot see whether a campaign is live, so `update_variant` always passes.
  - `job-watch.sh` (PostToolUse on `generate_campaign`, `render_video`, `video_commission`) writes paid-start markers under `${CLAUDE_PLUGIN_DATA}/jobs/` so the guard can flag a second start in the same session.
- `evals/`: one case per model-invocable skill, plus `squid-templates` and `brand-page`, in the `claude plugin eval` layout (`prompt.md` + `graders/*.md`), plus `run-smoke.sh`, a `claude -p` runner for hosts where `plugin eval` is not enabled.
- `server.json`: official MCP registry manifest (`io.sparkletree/sparkletree`). Its version tracks the hosted server, not the plugin; see "Versions" in README.md.
- `gemini-extension.json`: Gemini CLI manifest; points at the same server and uses this file as context. Same version as `.claude-plugin/plugin.json`.
- Directory-submission runbooks (one file per venue, ordered checklist, rulings) live in the private monorepo at `sparkletree-project/docs/plugin-submissions/`, not here. Nothing is submitted by agents without the rulings named there.
- `openai/`: the skills-only bundle for the OpenAI plugin submission, generated by `scripts/build-openai-bundle.sh` and gitignored. Build it right before zipping for the OpenAI portal. It must never be committed: the claude.ai and Claude desktop marketplace importer walks the whole repository and rejects the plugin when it finds a nested `.claude-plugin/plugin.json` ("plugin.json must be at .claude-plugin/plugin.json at the plugin root; found nested").

## Tool names

The skills are written for the 17-tool `external_default` surface. Verify against `mosaic/lib/mcp/toolGates.ts` and `mosaic/tests/mcp/manifest-external-surface.test.ts` in the monorepo before changing a tool name here, and against the handler (`mosaic/lib/mcp/*Consolidated.ts`, `squidTemplates.ts`, `squidComponentChecks.ts`) before writing what an action does, costs or needs.

## Checks before a commit

```sh
claude plugin validate --strict .                            # resolves to the marketplace file only
claude plugin validate --strict .claude-plugin/plugin.json   # the plugin itself, hooks included
claude plugin validate --strict skills
claude plugin validate --strict agents
sh -n scripts/*.sh
sh scripts/test-hooks.sh
sh scripts/ci-validate.sh && sh scripts/ci-check-bump.sh
sh scripts/test-ci-check-bump.sh
sh scripts/test-directory-transform.sh
scripts/build-openai-bundle.sh   # output is gitignored; zip openai/ for the OpenAI portal
```

Writing rules for anything a person reads: plain sentences, sentence-case headings, no em dashes, no marketing adjectives, say what happens and who pays for what. Never the word "brief" in user-facing copy; server identifiers such as `campaign_brief` and `briefMd` stay as they are. When a text says what SparkleTree is, take the wording from the canonical description (`docs/about-sparkletree.md` in the monorepo) and never reuse a retired one.
