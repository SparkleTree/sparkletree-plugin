# Setup

From nothing to a first campaign. Each step says what happens and what it costs.

## 1. A SparkleTree workspace

Sign up at https://app.sparkletree.io/sign-up. Onboarding creates your workspace. The AI connection cannot create an account or a workspace; a person does this once.

## 2. Install the plugin

Claude Code:

```
/plugin marketplace add SparkleTree/sparkletree-plugin
/plugin install sparkletree@sparkletree
```

Other hosts: see the install section of the [README](README.md).

## 3. Sign in

The plugin declares the MCP server. On the first session, run `/mcp`, choose sparkletree, and complete the browser sign-in with your SparkleTree account. If the tools do not appear afterwards, start a new session; servers load at session start.

## 4. Orientation

Run `/sparkletree:setup`. It confirms which workspace you are in, reads what exists (brand book, products, campaigns) and offers the next steps in order. Or paste the orientation prompt from https://docs.sparkletree.io/developers/agents/ and ask "What can you do in my workspace?"

## 5. First campaign

`/sparkletree:launch https://your-site/products/one-product` or `/sparkletree:launch <a one-sentence goal>`. You see the brief before anything is generated, approve it, and get a live URL at the end. Generation spends credits from the workspace's monthly pool; publishing is free.

## 6. Where it runs

Publishing puts the campaign on your brand page (`<name>.sparkletree.io` or your domain). To put it on your own site, screens or QR codes, ask for it in plain words; the surfaces-and-embed skill covers the script tag, the React SDK and signage.

## What asks for confirmation

Reads never ask. Publish, deploy, delete, and anything that generates or renders ask first, in the conversation and again through the plugin's spend-guard hook. The hook's message names the tool and what it spends or changes.

## If something fails

- Tools missing: new session, then `/mcp`.
- 401 or sign-in loop: `/mcp`, sparkletree, authenticate; or remove and re-add the connector.
- "connection failed" after a successful sign-in: the account has no workspace yet; finish onboarding at https://app.sparkletree.io.
- 429: 120 requests per minute per token; wait and retry.
- A message at session start that SparkleTree did not answer: the health check at `https://app.sparkletree.io/api/health` timed out (2 s). Try a read; if it fails too, wait and retry.
- Blocked with `precondition_failed` or `entitlement_required`: the workspace's quota, credits or plan blocks the action. Published campaigns keep serving.

The troubleshoot-connection skill walks the same list with more detail. Support: support@sparkletree.io (workspace name, tool, error code, time; never the token).

## Remove

`/plugin uninstall sparkletree` removes the skills, agents, hooks and server declaration. Revoke a hand-added connector in the client's settings. Disable API keys under Settings, API keys in the dashboard.
