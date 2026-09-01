---
name: setup
description: SparkleTree campaign plugin setup, run right after install with the sparkletree setup skill. Checks the account prerequisite (a SparkleTree workspace, sign-up link if none), connects and authenticates the MCP server, runs the orientation calls, and walks to a first campaign in about thirty minutes.
---

# Set up SparkleTree

Walk the user from a fresh install to a first campaign. Ask one question at a time. Do not spend credits without a yes.

## 1. Account

Ask whether they have a SparkleTree workspace. If not: https://app.sparkletree.io/sign-up creates the account and the onboarding flow creates the workspace. The connection cannot create either. Wait until they have one.

## 2. Connect

The plugin already declares the server (`https://app.sparkletree.io/api/mcp`). Ask the user to add the SparkleTree connector in their host and complete the browser sign-in. If the tools are still absent afterwards, start a new session; MCP servers load at session start.

## 3. Orientation

Run these and report in four lines:

1. `get_platform_info` `topic: "organization"`: workspace name, plan, counts.
2. Read `mosaic://capabilities` if resources are available, else `get_platform_info` `topic: "tool_profiles"`.
3. `query_products` `action: list` (limit 5) and `query_campaigns` `action: list` (limit 5).
4. `query_brand` `action: get`: is the brand book filled?

## 4. First thirty minutes

Offer, in this order, and do only what the user picks:

1. Brand book empty: the `brand-voice-sync` skill from their website. Admin role needed.
2. No products: import one from a URL (`manage_products` `import_from_url`, paid inference, confirm) or create one by hand.
3. First campaign: the `launch-campaign` skill. The brief is shown before anything is generated.
4. Where it runs: publishing puts it on the brand page; the `surfaces-and-embed` skill for a website, screen or QR.

## 5. What to remember

Tell the user, once: reads are free; publish, deploy, delete and anything that generates or renders asks first (this plugin adds a hook that asks as well); credits come from the workspace's monthly pool; everything runs under their own account and role; removing the connector or the plugin ends access.

Point to `the sparkletree launch skill`, `the sparkletree digest skill`, `the sparkletree status skill` and, if something fails, the `troubleshoot-connection` skill.
