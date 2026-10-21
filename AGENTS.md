# SparkleTree plugin: orientation for agents

You are in the SparkleTree plugin repository. It packages skills, two agents, one hook and one remote MCP server declaration for Claude Code, Codex, ChatGPT, Gemini CLI, Cursor and any MCP client. The server itself is not in this repo; it runs at `https://app.sparkletree.io/api/mcp` and is owned by the SparkleTree monorepo.

## If you are here to use SparkleTree

Read `skills/sparkletree/SKILL.md` first. It carries the rules that every other skill assumes: read `mosaic://capabilities`, read before write, confirm before publish, deploy, delete or credit spend. `skills/sparkletree/references/tools.md` is the tool table.

## If you are here to change the plugin

Layout (only `plugin.json` and `marketplace.json` live in `.claude-plugin/`; everything else sits at the root):

- `.claude-plugin/plugin.json`: manifest. `name` is `sparkletree` and must not change (it namespaces skills and agents, and scopes MCP tool names to `mcp__plugin_sparkletree_sparkletree__<tool>`).
- `.claude-plugin/marketplace.json`: one-plugin marketplace with `source: "./"`.
- `.codex-plugin/plugin.json`: Codex manifest. Same identity and version as `.claude-plugin/plugin.json`, plus the `interface` block the OpenAI portal reads (display name, category, links). It names no logo file: the logo is uploaded in the OpenAI portal, and Anthropic's directory validator holds any file that names an image path for review. Paths are relative and start with `./`; `skills`, `mcpServers` and `hooks` point at the same files Claude Code uses.
- `.mcp.json`: the remote server. Loads as `plugin:sparkletree:sparkletree`, so its tools are `mcp__plugin_sparkletree_sparkletree__<tool>`. When the user already has SparkleTree as a claude.ai connector for the same URL, Claude Code suppresses the plugin's copy as a duplicate (debug log: "Lazy dedup") and the tools appear under the connector's own server id (`mcp__<connector-id>__<tool>`).
- `skills/<name>/SKILL.md` plus `references/`: thirteen model-invocable skills and two user-invoked commands (`setup`, `launch`, both `disable-model-invocation: true`). Descriptions open with SparkleTree and the main use case, stay under 460 characters, and never rely on the description alone: when the host's skill listing overflows, only the name survives, so the name must say what the skill does. Bodies stay under 500 lines; long material goes in `references/`.
- `agents/`: `campaign-reviewer` and `analytics-digest`, both read-only via `disallowedTools` listing every write tool (including `upload_asset`) under both the plugin-scoped and the bare server name. A claude.ai connector's tool ids cannot be named there, so each agent's instructions forbid write tools under any server name.
- `hooks/hooks.json`, `scripts/check-connector.sh`: the one hook, POSIX sh, no jq. There is no PreToolUse hook: the skills confirm spend and live changes in chat, and the server refuses what the user's role, plan, credits or daily limits do not allow, with an error that names the remedy. The other files under `scripts/` are maintainer tooling (jq, git, curl): `bump-version.sh` moves a version, `ci-validate.sh` and `ci-check-bump.sh` are the push checks, `ci-tag.sh` tags on main (see "Versions" in README.md), `test-hooks.sh` runs the session hook against a healthy and an unreachable server; `test-ci-check-bump.sh` checks which changes need a bump.
  - `check-connector.sh` (SessionStart: startup, clear, compact) curls `https://app.sparkletree.io/api/health` (`SPARKLETREE_HEALTH_URL` overrides) with a two-second limit, adds one routing line to the context (`SPARKLETREE_SESSION_CONTEXT=off` drops it), is silent on success apart from that line, and always exits 0.
- `evals/`: one case per model-invocable skill, plus `squid-templates` and `brand-page`, in the layout that Claude Code's plugin eval command reads (`prompt.md` + `graders/*.md`).
- `.gitlab-ci.yml`: only an `include:` of `docs/plugin-submissions/plugin-ci/gitlab-ci.yml` in the monorepo. Change CI there. The jobs run in this project with its CI variables and call the scripts here. The definition stays out of this repo because the directory validator reads every file here as plugin content and holds the listing over the registry signing key and tool downloads.
- `server.json`: official MCP registry manifest (`io.sparkletree/sparkletree`). Its version tracks the hosted server, not the plugin; see "Versions" in README.md.
- `gemini-extension.json`: Gemini CLI manifest; points at the same server and uses this file as context. Same version as `.claude-plugin/plugin.json`.
- Directory-submission runbooks (one file per venue, ordered checklist, rulings) live in the private monorepo at `sparkletree-project/docs/plugin-submissions/`, not here. Nothing is submitted by agents without the rulings named there.
- The OpenAI submission bundle is built outside this repo, by `docs/plugin-submissions/build-openai-bundle.sh` in the monorepo, from a checkout of this repo. Never commit a bundle here: it contains a nested `.claude-plugin/plugin.json`, which makes the claude.ai and Claude desktop marketplace importer reject the plugin, and Anthropic's directory validator holds any file here that names that path. `ci-validate.sh` fails if an `openai/` folder is present.

## Tool names

The skills are written for the 15-tool `external_default` surface. Every client, Anthropic's plugin directory included, connects to the same server URL; there is no separate directory server or branch. Verify against `mosaic/lib/mcp/toolGates.ts` and `mosaic/tests/mcp/manifest-external-surface.test.ts` in the monorepo before changing a tool name here, and against the handler (`mosaic/lib/mcp/*Consolidated.ts`, `squidTemplates.ts`, `squidComponentChecks.ts`) before writing what an action does, costs or needs.

## Checks before a commit

```sh
claude plugin validate --strict .                            # resolves to the marketplace file only
claude plugin validate --strict .claude-plugin/plugin.json   # the plugin itself, hooks included
claude plugin validate --strict skills
claude plugin validate --strict agents
sh scripts/test-hooks.sh
sh scripts/ci-validate.sh && sh scripts/ci-check-bump.sh
sh scripts/test-ci-check-bump.sh
```

Writing rules for anything a person reads: plain sentences, sentence-case headings, no em dashes, no marketing adjectives, say what happens and who pays for what. Never the word "brief" in user-facing copy; server identifiers such as `campaign_brief` stay as they are. When a text says what SparkleTree is, take the wording from the canonical description (`docs/about-sparkletree.md` in the monorepo) and never reuse a retired one.
