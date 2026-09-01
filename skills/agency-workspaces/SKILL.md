---
name: agency-workspaces
description: SparkleTree campaign operations across several client workspaces. One connection or API key per workspace, confirm scope before every batch, tool profiles and call codes, role inheritance and revocation. Use when an agency or a headless agent manages more than one SparkleTree workspace or asks about API keys, profiles or call codes.
---

# Agency and multi-workspace operations

One MCP connection is bound to one workspace. There is no cross-workspace query and no way to switch inside a session. The expensive mistake in agency work is publishing into the wrong client; every rule below exists to prevent it.

## Connections

- Interactive hosts: one connector entry per client workspace, each signed in as a user who belongs to that workspace. Name them by client.
- Headless agents and scripts: one workspace API key per client, created by a human in the dashboard under Settings > API keys, sent as the `x-api-key` header to `https://app.sparkletree.io/api/mcp`. Keys carry workspace access; store them in a secrets manager, never in a repo. Disable a key the day its automation retires.
- CLI tokens exist for the sparkletree CLI; the same scoping applies.

## Scope check, every batch

Before the first write in any batch, and again after any switch:

1. `get_platform_info` `topic: "organization"`.
2. Echo the workspace name to the user in the same message as the plan.
3. Only then run the recipe (launch, review, digest, video) for that workspace.

Never infer the workspace from memory or from the campaign names you saw earlier.

## Roles

Connections inherit the signed-in user's role: admin, editor, member or viewer. A reporting connection should belong to a viewer; a publishing connection to a member or editor; brand writes need an admin. Demoting or removing the user cuts every connection they made.

## Profiles and call codes

The bare URL serves `external_default`. Narrower profiles (analytics_read, campaign_ops, video_ops and others) are selected with `?profile=<call-code>`; the call code is a secret provisioned by the workspace operator, not the profile name. Profile names are rejected and fall back to the minimal discovery profile. Profiles change which tools are visible, never what the user may do. Use a narrow profile for a single-job agent so the tool list stays small and accidents stay impossible. Discover the live list with `get_platform_info` `topic: "tool_profiles"`.

## Cross-client reporting

Run the digest (the `sparkletree:analytics-digest` agent or `skills/sparkletree` plus `query_analytics`) once per connection and merge client-side. Label every number with its workspace. Impressions and Reach stay separate per workspace; do not sum Reach across workspaces, sessions are per site.

## Revocation

OAuth: remove the connector in the client; access ends at the next call. API keys: disable in Settings > API keys (admin, immediate). Users: change the role or remove the member.

## Rate limits

120 requests per minute per token. Fan-out across workspaces means separate tokens and separate budgets; a `429` on one connection does not affect another. Back off exponentially on `429`.
