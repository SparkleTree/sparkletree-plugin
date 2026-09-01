# Changelog

Any change to a tool schema on the server bumps the plugin version, gets a note here for the OpenAI re-review, and is batched into a Cursor release.

## 0.1.0 (unreleased)

First version of the plugin.

- Manifest, one-plugin marketplace, MCP server declaration for `https://app.sparkletree.io/api/mcp`.
- Eight model-invocable skills (`sparkletree`, `launch-campaign`, `review-variants`, `brand-voice-sync`, `surfaces-and-embed`, `video-from-winner`, `agency-workspaces`, `troubleshoot-connection`) and four user-invoked commands (`setup`, `launch`, `digest`, `status`).
- Two read-only agents: `campaign-reviewer`, `analytics-digest`.
- Session-start health check and a pre-tool spend guard, both POSIX sh without dependencies.
- Eval cases for every model-invocable skill, plus a `claude -p` fallback runner.
- `server.json` for the official MCP registry (`io.sparkletree/sparkletree`), `gemini-extension.json`, and an OpenAI skills-only bundle generated from the same skills.

Tool surface: the skills target the 15-tool default that the pending server release introduces, where the read actions of `manage_brand`, `manage_surfaces` and `video_commission` move to `query_brand`, `query_surfaces` and `query_video_commissions`. On a server that still exposes the 12-tool surface, use `manage_brand action=get`, `manage_surfaces operation=list_surfaces|get_surface|list_zones` and `video_commission action=list|get` for those reads; everything else is unchanged.
