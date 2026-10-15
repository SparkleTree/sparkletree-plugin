# Setup

From nothing to a first campaign. Each step says what happens and what it costs.

## 1. A SparkleTree workspace

Sign up at https://app.sparkletree.io/sign-up. Onboarding creates your workspace. The AI connection cannot create an account or a workspace; a person does this once.

## 2. Install the plugin

Claude Code:

```
/plugin marketplace add https://gitlab.com/sparkletree/sparkletree-plugin.git
/plugin install sparkletree@sparkletree
```

Claude.ai and Claude desktop: Customize, Plugins, Add, Add marketplace, Add from a repository, paste the same GitLab URL, Sync, then install `sparkletree` from Browse.

Other hosts: see the install section of the [README](README.md).

## 3. Sign in

The plugin declares the MCP server. On the first session, run `/mcp`, choose sparkletree, and complete the browser sign-in with your SparkleTree account. If the tools do not appear afterwards, start a new session; servers load at session start.

## 4. Orientation

Run `/sparkletree:setup`. It confirms which workspace you are in, reads what exists (brand book, products, campaigns) and offers the next steps in order. Or paste the orientation prompt from https://docs.sparkletree.io/developers/agents/ and ask "What can you do in my workspace?"

## 5. First campaign

`/sparkletree:launch https://your-site/products/one-product` or `/sparkletree:launch <a one-sentence goal>`. You see the campaign plan before anything is generated, approve it, and get a live URL at the end. Generation spends credits from the workspace's monthly pool, including credits for each AI image, set aside when it starts; publishing is free.

## 6. Where it runs

Publishing puts the campaign on your brand page (`<name>.sparkletree.io` or your domain). To put it on your own site, screens or QR codes, ask for it in plain words; the surfaces-and-embed skill covers the script tag, the React SDK and signage.

## What asks for confirmation

Reads never ask. Two actions that change no campaign data still ask, because they use a daily workspace allowance: a browser check of a Squid design (`check_component`) and ranking the template library (`match_templates`). Publish, deploy, delete, and anything that generates, renders or runs in a sandbox ask first, in the conversation and again through the plugin's spend-guard hook. The hook's message names the tool and what it spends or changes. Drafts (a brand page draft, a design draft) do not ask.

In auto, bypassPermissions and dontAsk modes no prompt can appear, so the hook refuses a credit-spending call once and the model asks you in chat; the same call made again within 15 minutes goes through. The hook reads each call with jq. Without jq it cannot tell a draft from a publish, so it asks before every SparkleTree write (and refuses it once in those three modes); install jq for drafts and other free writes to go through without a prompt. Two environment switches change the plugin's behaviour: `SPARKLETREE_SPEND_GUARD=prompt-only` keeps the prompts but drops the refuse-once step, `SPARKLETREE_SPEND_GUARD=off` turns the hook off, and `SPARKLETREE_SESSION_CONTEXT=off` keeps the one routing line out of the model's context at session start.

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
