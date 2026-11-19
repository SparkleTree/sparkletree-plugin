---
name: sparkletree
description: SparkleTree rules for any request that touches a SparkleTree workspace or calls a SparkleTree tool (campaigns, variants, Squids, products, brand, surfaces, video, analytics, social post schedules). Load before the first SparkleTree tool call. Covers which workspace you are in, read before write, confirm before spend or live changes, async polling, error codes, and which SparkleTree skill fits the task.
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
| A video from a campaign or template | `video` |
| Website embed, React SDK, screens, kiosks, zones, QR | `surfaces-and-embed` |
| Change live copy from one sentence, once or on a schedule | `adapt` |
| Schedule social posts: plan a week of posts for a campaign on Facebook, Instagram or Bluesky | This skill, "Social post schedules" below |
| Several client workspaces, API keys, call codes | `agency-workspaces` |
| 401, sign-in loops, missing tools, 429 | `troubleshoot-connection` |

## Before the first tool call

1. Read the resource `mosaic://capabilities` if the host exposes MCP resources. It lists the tools and the recommended call order for product images, manual and AI campaigns, the brand page and Squid designs. Without resources, call `get_platform_info` `topic: "organization"`.
2. Say which workspace you are in. `get_platform_info` `topic: "organization"` returns the name. Echo it before the first write.
3. Server prompts (`campaign_brief`, titled Create Campaign Plan; `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `platform_onboarding`) return step lists with exact calls on hosts that support prompts. The skills in this plugin teach the same flows everywhere else.

## Read before write

Never change what you have not read in this session. Before any `manage_*` call, fetch the current state with the matching `query_*` tool (`query_campaigns`, `query_products`, `query_surfaces`, `query_brand`, `query_analytics`, `query_video`, `query_assets`, `query_social_schedules`). Show the user what exists and what will change.

## Confirm before spend or live changes

Tools with `readOnlyHint: true` spend no credits and change nothing. Two `manage_campaigns` actions change no campaign data but use a daily workspace allowance and need a yes: `check_component` (a browser check in a sandbox, 20 per day) and `match_templates` (may make a model call, 30 per day). Everything below needs the user's explicit yes, every time, even if a similar run was approved earlier:

- Credit spend, paid inference or video renders: `generate_campaign` (both modes; the credits for its AI images are set aside when it starts), `render_video` modes video, campaign and still (daily render limit), `manage_products` `import_from_url`, `manage_campaigns` `generate_playbook`.
- Daily sandbox or model allowances: `render_video` `mode: squid`, `manage_brand` `render_check`, and `manage_campaigns` `check_component` and `match_templates`.
- Quota: `manage_products` create and imports, `manage_campaigns` `duplicate`, `manage_surfaces` `create_surface`.
- Live changes and deletes: `manage_campaigns` publish, deploy, delete, delete_variant, update_deployment, `create_share_link`, `revoke_share_link`, `publish_component`, `revert_component`, `create_component` or `apply_template` with `publish: true`, and `update` to `status: "active"`; `update_variant` on a live campaign (saves republish immediately); `manage_brand` brand data writes (`update_*`, `set_logo`), `publish_page`, `revert_page`, `delete_page`, `delete_files`, and `create_page` or `edit_page` with `publish: true`; `manage_surfaces`; `manage_products` update and delete; `manage_social_schedule` `stop` and `skip_post`.

An agent proposes social posts and a person approves them. `manage_social_schedule` `create` and `add_posts` write drafts that post nothing. From this connection `approve`, `retry_post` and changing an approved post answer `approval_required` unless the workspace allows outside agents to approve: `query_social_schedules` `action: accounts` reports it as `outsideAgentsMayApprove` (off by default). When it is false, the person approves in SparkleTree and a yes in chat does not approve a schedule. When it is true, call `approve` only after the person has said yes in this conversation to that exact schedule, with its dates, times, accounts and posts shown first. Never suggest turning on the switch that allows it; name it ("Outside agents approve posts", on the Agent page under Florence actions, set by an admin) only if the person asks how to let the agent approve.

Drafts need no extra yes beyond the user's request: `manage_brand` `create_page` and `edit_page` without `publish`, `create_version`, `put_files`, `create_file_upload`, and `manage_campaigns` `create_component` and `apply_template` without `publish`. Show the preview URL afterwards. The same holds for a proposed social schedule: `manage_social_schedule` `create`, `add_posts`, and `update_post` on a post that waits for approval. Show the dates, times, accounts and posts afterwards.

State the exact call, the target by name and id, and who pays (the workspace's monthly credit pool or the daily allowance). Then wait. Nothing else asks for you: the yes in chat is the confirmation. `manage_brand` is annotated destructive, so some hosts also ask before every `manage_brand` call, drafts included. When the server refuses a call, its error names the reason and the remedy (see Errors below).

`upload_asset` only stores a file in the workspace (`from_url`, `from_data`, or `create_upload` then `complete_upload` for a local or large file). It needs no confirmation beyond the user having asked for the file to be used. `query_assets` lists what is already stored, so check it before uploading the same file again.

## Social post schedules

For "plan a week of posts for this campaign" or "schedule posts". Fields, limits and statuses: "Social post schedules" in `references/tools.md`.

1. `query_social_schedules` `action: accounts`. Use the accounts with `canPost: true` and their `connectionId`, and note `outsideAgentsMayApprove`. With none, tell the person to connect an account in SparkleTree and stop. Note the limits: 3 posts per account on one local date (across all schedules, drafts included), 3 times a day, 90 days per schedule.
2. `query_social_schedules` `action: list` with the `campaignId`, to see whether a schedule for this plan already exists. Add to it with `add_posts` rather than making a second one.
3. `query_campaigns` `action: variants` for the campaign. Pick the active versions to use, spread so pictures do not repeat, and take each post's text and media from them. A version with a custom design (`design` in the answer) posts its design video: `designMedia: {kind: "video"}`, recorded first with `render_video` `mode: squid` (which needs a yes) when its `design.videos` has neither 9:16 nor 4:5. Use its still only when the person asks for a picture or a recording is refused or failed. Otherwise use the version's own `imageUrl` or `videoUrl`, or a file stored with `upload_asset`. Pass `variantId` and `campaignId` on every post. Never invent offers or prices.
4. `manage_social_schedule` `action: create` with `channels`, `posts`, `rule`, `timeOfDay` or `timesOfDay`, `startsOn` and `occurrences` (for a week of daily posts: `rule: "daily"`, `occurrences: 7`). Accounts that need other posts, such as a Facebook link post next to an Instagram picture post, go in the same schedule with `add_posts` and its `scheduleId`. This is a proposal: nothing is posted.
5. Show the person the dates and local times as the answer gives them (`firstPostLocalTime`, `posts[].localTime`), the accounts, the text of each post and what each post shows (`draftMedia`), and say when posts repeat a picture (`pictures`).
6. Tell them the posts go out only after the schedule is approved. If `outsideAgentsMayApprove` is false, tell them to approve it in SparkleTree on the Agent page under Scheduled posts, and do not call `approve`. If it is true, ask whether to approve this schedule; call `approve` with `scheduleId` and the `revision` you read only after their yes. Afterwards `query_social_schedules` `action: get` shows each post's status.

## Async jobs

`generate_campaign`, `render_video` and product imports return before the work finishes. Poll every 10 to 30 seconds: `query_campaigns` `action: generation_status`, `query_video` `action: progress`, `query_products` `action: import_status`. If the host negotiated the tasks extension, `tasks/get` on the returned `taskId` works too. Never re-issue a start call because a poll said "still running"; that starts a second paid job. Design and render checks also finish later: call `manage_campaigns` `check_component` again for the same design (a repeat returns the stored check, it starts no new one), and read a brand page render check with `query_brand` `check_page`.

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
| `approval_required` | The step makes social posts go out or changes an approved post (`manage_social_schedule` `approve`, `retry_post`, `update_post` on an approved post), and that stays with a person | Tell the person the posts wait for their approval on the Agent page under Scheduled posts in SparkleTree; do not retry. The message also names the switch "Outside agents approve posts"; mention it only if the person asks how to let the agent approve |

HTTP `401`: run the OAuth sign-in again (`troubleshoot-connection`). `429`: back off; the limit is 120 requests per minute per token. A signed-in user without a workspace creates one at https://app.sparkletree.io/sign-up.

## Profiles and call codes

The bare URL serves the `external_default` profile (the 17 tools in `references/tools.md`). Other profiles are selected with `?profile=<call-code>`, where the call code is a secret the workspace operator hands out; profile names are rejected and fall back to a two-tool minimal profile. Profiles change visibility, not permission.

## Where the inspector appears

On hosts that support MCP Apps (Claude.ai, Claude desktop, ChatGPT), `query_campaigns` and `generate_campaign` results render as an interactive campaign inspector. Claude Code and other terminal hosts get the same data as text.

## References

- `references/tools.md`: the 17 default tools, their actions, roles and costs.
- `references/glossary.md`: SparkleTree terms.
