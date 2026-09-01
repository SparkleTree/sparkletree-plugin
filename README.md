# SparkleTree plugin

SparkleTree makes marketing campaigns that adapt to where they run and answer customers in your brand's voice. This plugin connects your AI to your SparkleTree workspace and teaches it the campaign craft: it reads your products and brand book, writes a brief, generates variants, publishes to your web pages and screens, and reads back what performed. Everything runs under your own account and role.

You need a SparkleTree workspace. Create one at https://app.sparkletree.io/sign-up; the connection cannot create it for you.

## What you can ask

- "Show me what's in my SparkleTree workspace: which campaigns are live and what's my top performer this week?"
- "Import the product at https://example.com/products/aurora-lamp and draft a campaign brief for it. Show me the brief before generating anything."
- "How did my campaigns perform in the last 7 days? Which variant is winning, and what one change would you make?"

<!-- SCREENSHOT PLACEHOLDER 1: assets/listing/inspector-campaign-list.png. The campaign inspector rendering a query_campaigns list in Claude.ai (status badges, paging). Capture from a real session; do not fabricate. -->

<!-- SCREENSHOT PLACEHOLDER 2: assets/listing/inspector-generation.png. The inspector's generation-status view after generate_campaign, with variant previews. Capture from a real session; do not fabricate. -->

## Install

### Claude Code

```
/plugin marketplace add SparkleTree/sparkletree-plugin
/plugin install sparkletree@sparkletree
```

Then `/mcp`, choose sparkletree, and sign in with your SparkleTree account in the browser. Run `/sparkletree:setup` for a guided first half hour.

To try it without installing: `claude --plugin-dir ./sparkletree-plugin` from a clone.

### Skills only, any agent that reads Agent Skills

```
npx skills add SparkleTree/sparkletree-plugin
```

This installs the skills without the MCP server declaration, hooks or agents. Add the connector in your client separately (below).

### Claude.ai and Claude desktop

Settings, Connectors, Add custom connector, paste `https://app.sparkletree.io/api/mcp`, approve, sign in. SparkleTree is not yet in Anthropic's connector directory, so the custom connector is the route today.

### ChatGPT

Add a custom connector (MCP server) with the same URL, `https://app.sparkletree.io/api/mcp`, and sign in when prompted.

### Cursor and any MCP client

Point the client at `https://app.sparkletree.io/api/mcp` over streamable HTTP. An unauthenticated call returns 401 with OAuth resource metadata; a spec-compliant client discovers the authorization server, registers, opens the browser consent flow, and you sign in. Headless clients can send a workspace API key (Settings, API keys in the dashboard) as the `x-api-key` header instead.

### Gemini CLI

`gemini extensions install https://github.com/SparkleTree/sparkletree-plugin`. The manifest is `gemini-extension.json`.

## What is in the plugin

| Part | What it does |
|---|---|
| MCP server `sparkletree` | `https://app.sparkletree.io/api/mcp`, 15 tools: read tools for campaigns, products, surfaces, brand, analytics, video and commissions; write tools for the same; `generate_campaign` and `render_video`. Reads are marked read-only. |
| Skill `sparkletree` | How to work in a workspace: read `mosaic://capabilities` first, read before write, confirm before publish, deploy, delete or credit spend. |
| Skills `launch-campaign`, `review-variants`, `brand-voice-sync`, `surfaces-and-embed`, `video-from-winner`, `agency-workspaces`, `troubleshoot-connection` | One job each, from product URL to live link, variant critique, brand book setup, website and screen deployment (including the React SDK), video, multi-workspace operations, connection problems. |
| Commands `/sparkletree:setup`, `:launch`, `:digest`, `:status` | Guided setup, launch from an argument, weekly analytics digest, workspace status. Only you can run these. |
| Agents `campaign-reviewer`, `analytics-digest` | Read-only subagents. They return verdicts and proposals; the main conversation confirms and writes. |
| Hook: session start | A two-second health check of the server. Silent when it answers; one line when it does not. Never blocks. |
| Hook: spend guard | Before `generate_campaign`, `render_video`, `video_commission` create/approve/revise/cancel and `manage_campaigns` publish/deploy/delete, Claude Code asks you first and says what the call spends or changes. Reads are never intercepted. |

## Who pays for what

Reads are free. `generate_campaign`, `render_video`, `video_commission` and `manage_products import_from_url` draw from the workspace's monthly credit pool, the same one the dashboard uses. When credits or quota run out the action is blocked and published campaigns keep serving. The plugin itself is free and MIT licensed.

## Data

The plugin sends nothing anywhere except to `app.sparkletree.io` (the MCP server and its health endpoint). Tool calls run as you, in one workspace, with your role. Removing the connector or disabling the plugin ends access; disabling an API key does the same for headless clients. Privacy policy: https://app.sparkletree.io/legal/privacy. Terms: https://app.sparkletree.io/legal/terms.

## Documentation and support

- Agent-facing docs: https://docs.sparkletree.io/developers/agents/
- Setup and troubleshooting in this repo: [SETUP.md](SETUP.md)
- Support: support@sparkletree.io
- Rate limit: 120 requests per minute per token.

## Develop

```
claude plugin validate --strict .
claude plugin validate --strict skills
claude plugin validate --strict agents
claude --plugin-dir .
evals/run-smoke.sh            # or: claude plugin eval . --allow-tools Skill
scripts/build-openai-bundle.sh
```

Layout, tool-name notes and writing rules are in [AGENTS.md](AGENTS.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).
