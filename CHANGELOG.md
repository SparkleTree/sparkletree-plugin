# Changelog

Any change to a tool schema on the server bumps the plugin version, gets a note here for the OpenAI re-review, and is batched into a Cursor release.

## 0.1.2

- New command `/sparkletree:adapt [what should change, and when]`: one sentence becomes a live change to campaign copy, the active variant, the concierge or the brand voice, applied once now or as a scheduled task the host runs. Free writes only, brand content rules checked before every write, old versus new in every report. README and the Codex `defaultPrompt` list carry the example phrase.

## 0.1.1

- `.codex-plugin/plugin.json` for Codex and the OpenAI plugin portal, with `assets/icon.webp` (180 by 180).
- `surfaces-and-embed`: the publishable key is a signed credential required on every request; test keys work locally, live keys need a registered origin; `x-st-auth` / 401 `reason` + `remedy` troubleshooting.
- Stop committing the generated `openai/` bundle. Its nested `.claude-plugin/plugin.json` made the claude.ai and Claude desktop marketplace importer reject the plugin with "plugin.json must be at .claude-plugin/plugin.json at the plugin root; found nested". `scripts/build-openai-bundle.sh` still produces it, gitignored, for the OpenAI zip.
- `launch` skill description no longer uses angle brackets; the claude.ai importer flags them as XML.
- Install docs: the Claude Code marketplace command now uses the full GitLab URL (the `owner/repo` shorthand only resolves GitHub), and the claude.ai / desktop plugin route is documented.

## 0.1.0 (unreleased)

First version of the plugin.

- Manifest, one-plugin marketplace, MCP server declaration for `https://app.sparkletree.io/api/mcp`.
- Eight model-invocable skills (`sparkletree`, `launch-campaign`, `review-variants`, `brand-voice-sync`, `surfaces-and-embed`, `video-from-winner`, `agency-workspaces`, `troubleshoot-connection`) and four user-invoked commands (`setup`, `launch`, `digest`, `status`).
- Two read-only agents: `campaign-reviewer`, `analytics-digest`.
- Session-start health check and a pre-tool spend guard, both POSIX sh without dependencies. The guard matches the four spend and destructive tools under any MCP server name, because Claude Code drops the plugin's server when a claude.ai connector for the same URL is present and the tools then carry the connector's id.
- Eval cases for every model-invocable skill, plus a `claude -p` fallback runner.
- `server.json` for the official MCP registry (`io.sparkletree/sparkletree`), `gemini-extension.json`, and an OpenAI skills-only bundle generated from the same skills.

Tool surface: the skills target the 15-tool default that the pending server release introduces, where the read actions of `manage_brand`, `manage_surfaces` and `video_commission` move to `query_brand`, `query_surfaces` and `query_video_commissions`. On a server that still exposes the 12-tool surface, use `manage_brand action=get`, `manage_surfaces operation=list_surfaces|get_surface|list_zones` and `video_commission action=list|get` for those reads; everything else is unchanged.
