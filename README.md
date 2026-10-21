# SparkleTree plugin

This plugin lets Claude and other AI assistants work in your SparkleTree workspace. It connects the assistant to the SparkleTree MCP server and teaches it how the workspace fits together: it adds and imports products, sets up your brand book and brand page, writes a campaign plan for your approval, generates and reviews variants, designs Squid creatives or picks a ready-made template, publishes to your brand page, website and screens, and reads back what performed. It asks before anything that spends credits, goes live or deletes, and everything runs under your own account and role.

SparkleTree is a one-stop shop for building, managing and promoting your business online. It helps you establish your brand, create your web presence, improve how you appear in search and AI tools, and launch targeted marketing campaigns, all from one connected system. It then distributes those campaigns across every channel: websites and socials, digital signage and DOOH screens, kiosks, print and QR codes, and live streams, including NDI, with delivery across screen networks. More at https://sparkletree.io.

You need a SparkleTree workspace. Create one at https://app.sparkletree.io/sign-up; the connection cannot create it for you.

## What you can ask

- "Show me what's in my SparkleTree workspace: which campaigns are live and what's my top performer this week?"
- "Import the product at https://example.com/products/aurora-lamp and draft a campaign plan for it. Show me the plan before generating anything."
- "How did my campaigns perform in the last 7 days? Which variant is winning, and what one change would you make?"
- "Give the ad in my spring campaign its own design that matches my website, and show me a preview before it goes live."
- "Change the opening hours on my brand page to 8 to 18 on weekdays and show me the draft before it goes live."
- "Each morning at 6, scan the internet for the day's dominant meme and rewrite the hero body of my Aurora Lamp campaign to make a joke about it. Show me the first one before it goes live." (`/sparkletree:adapt` does this; the schedule runs in your host, the change is a free write, and every run reports old versus new.)

<!-- SCREENSHOT PLACEHOLDER 1: assets/listing/inspector-campaign-list.png. The campaign inspector rendering a query_campaigns list in Claude.ai (status badges, paging). Capture from a real session; do not fabricate. -->

<!-- SCREENSHOT PLACEHOLDER 2: assets/listing/inspector-generation.png. The inspector's generation-status view after generate_campaign, with variant previews. Capture from a real session; do not fabricate. -->

## Install

### Claude Code

```
/plugin marketplace add https://gitlab.com/sparkletree/sparkletree-plugin.git
/plugin install sparkletree@sparkletree
```

The full GitLab URL is required; the `owner/repo` shorthand only resolves GitHub. Then `/mcp`, choose sparkletree, and sign in with your SparkleTree account in the browser. Run `/sparkletree:setup` for a guided first half hour.

To try it without installing: `claude --plugin-dir ./sparkletree-plugin` from a clone.

### Claude.ai and Claude desktop (plugin)

Customize, Plugins, Add, Add marketplace, Add from a repository. Paste `https://gitlab.com/sparkletree/sparkletree-plugin.git`, choose the "Use" row that appears, and press Sync. The `sparkletree` plugin then shows under Browse for that marketplace; install it there. The MCP server inside the plugin asks you to sign in with your SparkleTree account on first use.

### Skills only, any agent that reads Agent Skills

```
npx skills add SparkleTree/sparkletree-plugin
```

This installs the skills without the MCP server declaration, hooks or agents. Add the connector in your client separately (below).

### Claude.ai and Claude desktop (connector only)

If you want only the MCP tools without the skills: Settings, Connectors, Add custom connector, paste `https://app.sparkletree.io/api/mcp`, approve, sign in. SparkleTree is not yet in Anthropic's connector directory, so the custom connector is the route today.

### ChatGPT

Add a custom connector (MCP server) with the same URL, `https://app.sparkletree.io/api/mcp`, and sign in when prompted.

### Cursor and any MCP client

Point the client at `https://app.sparkletree.io/api/mcp` over streamable HTTP. An unauthenticated call returns 401 with OAuth resource metadata; a spec-compliant client discovers the authorization server, registers, opens the browser consent flow, and you sign in. Headless clients can send a workspace API key (Settings, API keys in the dashboard) as the `x-api-key` header instead.

### Gemini CLI

`gemini extensions install https://gitlab.com/sparkletree/sparkletree-plugin`. The manifest is `gemini-extension.json`.

## What is in the plugin

| Part | What it does |
|---|---|
| MCP server `sparkletree` | `https://app.sparkletree.io/api/mcp`, 15 tools: read tools for campaigns, products, stored files, surfaces, brand, analytics and video, and the matching write tools, plus `generate_campaign`, `render_video` and `upload_asset`. Reads are marked read-only. |
| Skill `sparkletree` | How to work in a workspace: read `mosaic://capabilities` first, read before write, confirm before publish, deploy, delete or credit spend, and which skill fits the request. |
| Skills `launch-campaign`, `products`, `brand`, `squid-design`, `review-variants`, `analytics`, `status`, `video`, `surfaces-and-embed`, `adapt`, `agency-workspaces`, `troubleshoot-connection` | One job each: product URL or goal to a live link; products, photos and file uploads; brand book, voice, brand page and brand site; custom Squid designs, templates, design checks and design video; variant critique; results and reports; what is live and running; video renders from campaigns and templates; website, React SDK, screens and QR; a one-sentence live change, once or on a schedule; several client workspaces; connection problems. The model loads them when a request fits; you can also type `/sparkletree:<name>`. |
| Commands `/sparkletree:setup`, `/sparkletree:launch` | Guided first half hour, and a launch from a product URL or a goal. Only you can run these. |
| Agents `campaign-reviewer`, `analytics-digest` | Read-only subagents. They return verdicts and proposals; the main conversation confirms and writes. |
| Hook: session start | A two-second health check of the server, silent when it answers and one line when it does not, plus one routing line in the model's context that names the skills. Never blocks. |

## What the plugin runs, sends and fetches

- Tool calls go to `https://app.sparkletree.io/api/mcp` and run as you, in one workspace, with your role.
- At session start (`startup`, `clear`, `compact`), `scripts/check-connector.sh` sends one GET to `https://app.sparkletree.io/api/health` with curl, without credentials and with a two-second limit. Set `SPARKLETREE_HEALTH_URL` to check another address. Without curl it skips the check. It adds one line to the model's context that routes SparkleTree requests to the right skill; `SPARKLETREE_SESSION_CONTEXT=off` leaves that line out.
- Nothing else. The plugin has no telemetry and makes no other network calls. The hook script is POSIX sh and needs nothing but curl, which it skips when curl is missing.

## Who pays for what

- Reads are free. Two `manage_campaigns` actions change no campaign data but use a daily workspace allowance: `check_component` starts a browser check of a Squid design in a sandbox where browser checks are switched on (20 per workspace per day; its static checks are free), and `match_templates` may make a model call to rank templates (30 uncached matches per workspace per day, kept for 7 days).
- Credits, from the workspace's monthly pool that the dashboard also uses: `generate_campaign` (both modes) counts against the workspace's campaign generation quota, and the credits for each AI image are set aside when the call is accepted; with too few credits nothing starts.
- Paid AI inference on the workspace's behalf: `manage_products` `import_from_url` (which also fetches the page from the open web) and `manage_campaigns` `generate_playbook`.
- Daily render limits, not credits: `render_video` modes video, campaign and still render on SparkleTree's video service within a daily per-workspace limit.
- Sandbox allowances: `render_video` `mode: squid` records a design in a sandbox (20 per workspace per day, not on Starter); `manage_brand` `render_check` loads a brand page version in a sandbox (20 per workspace per day).
- Quota: products, campaigns (`duplicate` included) and surfaces count against the plan's limits.

When credits, an allowance or quota run out, the action is blocked with `precondition_failed` and published campaigns keep serving. The plugin itself is free and MIT licensed.

## Data

Tool calls run as you, in one workspace, with your role. Removing the connector or disabling the plugin ends access; disabling an API key does the same for headless clients.

- Privacy policy: https://app.sparkletree.io/legal/privacy
- Terms: https://app.sparkletree.io/legal/terms

## Documentation and support

- Agent-facing docs: https://docs.sparkletree.io/developers/agents/
- Setup and troubleshooting in this repo: [SETUP.md](SETUP.md)
- Support: support@sparkletree.io
- Rate limit: 120 requests per minute per token.

## Develop

```
claude plugin validate --strict .
claude plugin validate --strict .claude-plugin/plugin.json
claude plugin validate --strict skills
claude plugin validate --strict agents
sh scripts/test-hooks.sh
claude --plugin-dir .
claude plugin eval . --allow-tools Skill
scripts/build-openai-bundle.sh
```

Layout, tool-name notes and writing rules are in [AGENTS.md](AGENTS.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Versions

Four files carry a version. They describe two different things, so they do not all match, and that is by design.

| File | What it versions | Bump when |
| --- | --- | --- |
| `.claude-plugin/plugin.json` | The plugin package: skills, commands, agents, hooks | Anything in this repo that a user of the plugin can notice |
| `.codex-plugin/plugin.json` | The same package, for Codex and the OpenAI portal | Always together with the Claude manifest, same number |
| `gemini-extension.json` | The same package, for Gemini CLI | Always together with the Claude manifest, same number |
| `server.json` | The hosted MCP server at `https://app.sparkletree.io/api/mcp`, as listed in the official MCP registry | Only when the server's tools, resources, auth or endpoint change |

The rules:

- The three plugin manifests are one version. They ship from the same commit and describe the same files, so they always carry the same number.
- `server.json` follows the server, not the plugin. The server lives in the SparkleTree monorepo, and its version there (`MCP_SERVER_VERSION`) and the one here must agree; the monorepo's `mcp-version-sync` job fails a merge request while they differ. A skill or docs change here never bumps it.
- When a server change lands, both move: bump `server.json` to match the server, bump the plugin manifests because the skills that describe the tools changed, and name the registry version in the changelog entry (as 0.1.3 does for registry 1.0.2).

Releasing:

1. `scripts/bump-version.sh plugin 0.1.4` rewrites the three manifests and opens a changelog stub; `scripts/bump-version.sh server 1.0.3` rewrites `server.json` and adds a changelog line. Fill in the stub.
2. `sh scripts/ci-validate.sh && sh scripts/ci-check-bump.sh` runs the same checks CI runs.
3. Commit and push. On `main`, CI tags the commit `plugin-v<version>`, and the publish job tags `server-v<version>` once the registry lists that version.

What CI enforces on every push (`scripts/ci-validate.sh`, `scripts/ci-check-bump.sh`):

- The three plugin manifests agree, and `CHANGELOG.md` has a section for that version and mentions the current `server.json` version.
- A change under `skills/`, `agents/`, `hooks/`, `assets/`, to `.mcp.json`, to any of the three plugin manifests or the marketplace file, or to the hook scripts without a plugin bump fails. A manifest change that only moves its version is the bump itself and passes. Neither version may go backwards.
- On `main`, the registry publish reads `server.json` only. It skips when the registry already lists that version, and refuses when the version was published before or is lower than the registry's latest. A plugin-only release is therefore a no-op for the registry.

Tagging pushes with the job's own token, so there is no token to create or rotate. It needs one project setting: Settings, CI/CD, Job token permissions, "Allow Git push requests to the repository". Without it the tag job fails and says so.

The CI definition itself lives in the SparkleTree monorepo; `.gitlab-ci.yml` here only includes it. The registry signing key is a protected CI variable on this project and appears in no file in this repository.

Anthropic's plugin directory lists `main`: the same plugin and the same server (`https://app.sparkletree.io/api/mcp`) as every other install.
