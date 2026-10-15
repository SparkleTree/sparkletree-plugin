---
name: sparkletree
description: SparkleTree rules for any request that touches a SparkleTree workspace or calls a SparkleTree tool (campaigns, variants, Squids, products, brand, surfaces, video, analytics). Load before the first SparkleTree tool call. Covers which workspace you are in, read before write, confirm before spend or live changes, async polling, error codes, and which SparkleTree skill fits the task.
---

# SparkleTree orientation

SparkleTree builds, manages and promotes a business online and on screens: brand, website, SEO and AI visibility, and campaigns, from one connected system. Over this connection you work with the parts below. A campaign holds variants (the creatives). The creative unit is the Squid, a conversational ad with a kicker, headline, body, CTA and chips; a Squid can also carry a custom HTML design or a ready-made template. Campaigns deploy to surfaces (websites, the brand page, screens, kiosks, QR codes). Adaptive CVG learns which variant performs and shows it more often. Analytics report Impressions and Reach separately: headline Impressions include Meta Ads deliveries at day granularity and up, Reach is distinct SparkleTree sessions.

The MCP server is `https://app.sparkletree.io/api/mcp`. Every tool runs as the signed-in user, in one workspace, with that user's role. A connection cannot reach another workspace.

## Pick the skill

| The user wants | Skill |
|---|---|
| A new campaign from a product link or a goal | `launch-campaign` |
| Products, product photos, uploading a file, a CSV import | `products` |
| The brand book, voice, colours, concierge answers, the brand home page or a multi-page brand site | `brand` |
| A custom Squid design (their own HTML look), a ready-made template, a design check, or a video of a design | `squid-design` |
| Critique or compare variants, check copy is on brand | `review-variants` |
| Numbers: how campaigns did, which variant wins, a weekly report | `analytics` |
| What is live or running right now | `status` |
| A video from a campaign or template, or a commissioned film | `video` |
| Website embed, React SDK, screens, kiosks, zones, QR | `surfaces-and-embed` |
| Change live copy from one sentence, once or on a schedule | `adapt` |
| Several client workspaces, API keys, call codes | `agency-workspaces` |
| 401, sign-in loops, missing tools, 429 | `troubleshoot-connection` |

## Before the first tool call

1. Read the resource `mosaic://capabilities` if the host exposes MCP resources. It lists the tools and the recommended call order for product images, manual and AI campaigns, the brand page and Squid designs. Without resources, call `get_platform_info` `topic: "organization"`.
2. Say which workspace you are in. `get_platform_info` `topic: "organization"` returns the name. Echo it before the first write.
3. Server prompts (`campaign_brief`, titled Create Campaign Plan; `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `platform_onboarding`) return step lists with exact calls on hosts that support prompts. The skills in this plugin teach the same flows everywhere else.

## Read before write

Never change what you have not read in this session. Before any `manage_*` call, fetch the current state with the matching `query_*` tool (`query_campaigns`, `query_products`, `query_surfaces`, `query_brand`, `query_analytics`, `query_video`, `query_video_commissions`, `query_assets`). Show the user what exists and what will change.

## Confirm before spend or live changes

Tools with `readOnlyHint: true` spend no credits and change nothing. Two `manage_campaigns` actions change no campaign data but use a daily workspace allowance and need a yes: `check_component` (a browser check in a sandbox, 20 per day) and `match_templates` (may make a model call, 30 per day). Everything below needs the user's explicit yes, every time, even if a similar run was approved earlier:

- Credit spend, paid inference or video renders: `generate_campaign` (both modes; the credits for its AI images are set aside when it starts), `render_video` modes video, campaign and still (daily render limit), `video_commission` create, approve and revise (five a day, limited revision rounds), `manage_products` `import_from_url`, `manage_campaigns` `generate_playbook`.
- Daily sandbox or model allowances: `render_video` `mode: squid`, `manage_brand` `render_check`, and `manage_campaigns` `check_component` and `match_templates`.
- Quota: `manage_products` create and imports, `manage_campaigns` `duplicate`, `manage_surfaces` `create_surface`.
- Live changes and deletes: `manage_campaigns` publish, deploy, delete, delete_variant, update_deployment, `create_share_link`, `revoke_share_link`, `publish_component`, `revert_component`, `create_component` or `apply_template` with `publish: true`, and `update` to `status: "active"`; `update_variant` on a live campaign (saves republish immediately); `manage_brand` brand data writes (`update_*`, `set_logo`), `publish_page`, `revert_page`, `delete_page`, `delete_files`, and `create_page` or `edit_page` with `publish: true`; `manage_surfaces`; `manage_products` update and delete.

Drafts need no extra yes beyond the user's request: `manage_brand` `create_page` and `edit_page` without `publish`, `create_version`, `put_files`, `create_file_upload`, and `manage_campaigns` `create_component` and `apply_template` without `publish`. Show the preview URL afterwards.

State the exact call, the target by name and id, and who pays (the workspace's monthly credit pool or the daily allowance). Then wait. This plugin ships a hook that asks before every call in the lists above except `update_variant` (the hook cannot see whether the campaign is live) and `manage_products` `create`, `update` and `import_csv`; confirm those in chat. The hook is a backstop, not a substitute for asking. `manage_brand` is annotated destructive, so some hosts also ask before every `manage_brand` call, drafts included.

`upload_asset` only stores a file in the workspace (`from_url`, `from_data`, or `create_upload` then `complete_upload` for a local or large file). It needs no confirmation beyond the user having asked for the file to be used. `query_assets` lists what is already stored, so check it before uploading the same file again.

## Async jobs

`generate_campaign`, `render_video`, `video_commission` and product imports return before the work finishes. Poll every 10 to 30 seconds: `query_campaigns` `action: generation_status`, `query_video` `action: progress`, `query_video_commissions` `action: get`, `query_products` `action: import_status`. If the host negotiated the tasks extension, `tasks/get` on the returned `taskId` works too. Never re-issue a start call because a poll said "still running"; that starts a second paid job. Design and render checks also finish later: call `manage_campaigns` `check_component` again for the same design (a repeat returns the stored check, it starts no new one), and read a brand page render check with `query_brand` `check_page`.

## Pagination and lean responses

List actions use cursor pagination: pass `page.nextCursor` back as `cursor`. Follow the cursor until the question is answered, not until it is exhausted. `query_analytics` defaults `sections` to `["summary"]`; widen only when the task needs it.

## Errors

Every error is `{error: {code, message, remedy, details}}`. Read the remedy before retrying.

| Code | Meaning | Do |
|---|---|---|
| `invalid_input` | Wrong action or fields; `details.replacement` names a moved read action | Fix the call |
| `precondition_failed` | Quota, credits (including too few image credits for a campaign, with `details.creditsNeeded` and `creditsRemaining`), a daily cap, a state rule, or a question for the user (`details.code: PRODUCT_EXISTS`) | Read `details` and the remedy; ask the user when the remedy says so; never retry blindly |
| `forbidden` | The role or plan does not allow it | Tell the user who can do it |
| `entitlement_required` | A plan feature (`details.feature`) | Tell the user; do not retry |
| `not_configured` | The feature is switched off on this deployment (for example the Squid template library) | Say it is not available yet and offer the alternative; not a bug, do not retry |
| `upstream_error` | A site, store or render service failed | Retry once later; for imports read `details.reason` |
| `analytics_window_too_large` | Range too long for the granularity | Narrow the range or coarsen the granularity |

HTTP `401`: run the OAuth sign-in again (`troubleshoot-connection`). `429`: back off; the limit is 120 requests per minute per token. A signed-in user without a workspace creates one at https://app.sparkletree.io/sign-up.

## Profiles and call codes

The bare URL serves the `external_default` profile (the 17 tools in `references/tools.md`). Other profiles are selected with `?profile=<call-code>`, where the call code is a secret the workspace operator hands out; profile names are rejected and fall back to a two-tool minimal profile. Profiles change visibility, not permission.

## Where the inspector appears

On hosts that support MCP Apps (Claude.ai, Claude desktop, ChatGPT), `query_campaigns` and `generate_campaign` results render as an interactive campaign inspector. Claude Code and other terminal hosts get the same data as text.

## References

- `references/tools.md`: the 17 default tools, their actions, roles and costs.
- `references/glossary.md`: SparkleTree terms.
