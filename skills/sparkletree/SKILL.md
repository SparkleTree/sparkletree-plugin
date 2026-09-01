---
name: sparkletree
description: SparkleTree campaign platform orientation for any task that touches a SparkleTree workspace, including campaigns, variants, Squids, surfaces, brand book, products and analytics. Load before the first tool call. Read mosaic://capabilities, read before you write, confirm before publish, deploy, delete or credit spend, and use the server prompts where the host supports them.
---

# SparkleTree orientation

SparkleTree is a marketing platform. A campaign holds variants (the creatives). The creative unit is the Squid, a conversational ad with a kicker, headline, body, CTA and chips. Campaigns deploy to surfaces (websites, brand page, screens, kiosks, QR codes). Adaptive CVG learns which variant performs and shows it more often. Analytics report Impressions (raw deliveries) and Reach (distinct sessions) separately.

The MCP server is `https://app.sparkletree.io/api/mcp`. Every tool runs as the signed-in user, in one workspace, with that user's role. There is no way to reach another workspace from a connection.

## Before the first tool call

1. Read the resource `mosaic://capabilities` if your host exposes MCP resources. It is the live list of tools, prompts and recommended flows for this workspace and it beats guessing. If the host has no resource support, call `get_platform_info` with `topic: "organization"` and then `topic: "tool_profiles"`.
2. Say which workspace you are in. `get_platform_info` `topic: "organization"` returns the name. Echo it back before the first write.
3. Check whether a server prompt covers the task before improvising: `campaign_brief`, `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `ai_studio_image_workflow`, `platform_onboarding`. Each returns a step list with exact tool calls. The skills in this plugin teach the same flows for hosts without prompt support.

## Read before write

Never change what you have not read in this session. Before any `manage_*` call, fetch the current state with the matching `query_*` tool (`query_campaigns`, `query_products`, `query_surfaces`, `query_brand`, `query_analytics`, `query_video`, `query_video_commissions`). Show the user what exists and what will change.

## Confirm before spend or mutation

Tools with `readOnlyHint: true` are free to call. Everything else needs the user's explicit yes, every time, even if a similar run was approved earlier:

- Credit spend: `generate_campaign` (both modes), `render_video` (all modes), `video_commission` create, approve and revise, `manage_products` `import_from_url` (paid inference plus open web).
- Live marketing changes: `manage_campaigns` publish, deploy, delete, delete_variant, update_deployment; `manage_surfaces`; `manage_brand`; `manage_products` create, update, delete.

State the exact call, the target by name and id, and who pays (the workspace's monthly credit pool). Then wait. This plugin also ships a hook that asks before the spend tools run; the hook is a backstop, not a substitute for asking.

## Async jobs

`generate_campaign`, `render_video`, `video_commission` and CSV import return before the work finishes. Poll at a reasonable interval (10 to 20 seconds): `query_campaigns` `action: generation_status`, `query_video` `action: progress`, `query_video_commissions` `action: get`, `query_products` `action: import_status`. If the host negotiated the tasks extension, `tasks/get` on the attached handle works too. Never re-issue a start call because a poll said "still running"; that starts a second paid job.

## Pagination and lean responses

List actions use cursor pagination: pass `page.nextCursor` back as `cursor`. Follow the cursor until the question is answered, not until it is exhausted. `query_analytics` defaults `sections` to `["summary"]`; widen only when the task needs it.

## Profiles and call codes

A bare URL gets the `external_default` profile (the 15 tools in `references/tools.md`). Narrower or wider profiles are selected by appending `?profile=<call-code>`, where the call code is a secret the workspace operator hands out; profile names are rejected. Profiles change visibility, not permission. Discover them with `get_platform_info` `topic: "tool_profiles"`.

## Errors

Every error carries a code, a message and usually a `remedy`. Read the remedy before retrying. `401`: run the OAuth bootstrap again. `429`: back off (limit is 120 requests per minute per token). `precondition_failed` or `entitlement_required`: the workspace plan or quota blocks the action; tell the user, do not retry. If the server says the signed-in user has no workspace, the user creates one at https://app.sparkletree.io/sign-up.

## Where the inspector appears

On hosts that support MCP Apps (Claude.ai, Claude desktop, ChatGPT), `query_campaigns` and `generate_campaign` results render as an interactive campaign inspector. Claude Code and other terminal hosts get the same data as text; nothing is lost.

## References

- `references/tools.md`: the 15 default tools, their actions and which ones cost credits.
- `references/glossary.md`: SparkleTree terms.
