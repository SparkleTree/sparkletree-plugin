# The default tool surface

Seventeen tools on the bare URL (`external_default`). Reads and writes never share a tool. Every tool takes one flat input with a discriminator (`action`, `mode`, `operation` or `topic`); the handler checks the fields for that action and answers `invalid_input` naming the bad ones. `organizationId` is optional everywhere and comes from the sign-in. Verified against the server source on 2026-10-15 (monorepo main 4be3e1bed, plus the final 1.0.3 change that moved `check_component` and `match_templates` to `manage_campaigns`), and the 1.0.4 `query_analytics` `siteActivity` section (monorepo !1464, 2026-10-16). Tool list checked again for server 1.0.5 (2026-10-17). `query_social_schedules` and `manage_social_schedule` checked against server 1.9.0 (monorepo !1720, commit 2c6f91890, 2026-11-19), which added both tools.

| Tool | Read or write | Actions | Notes |
|---|---|---|---|
| `get_platform_info` | read | `topic: health, organization, tool_profiles` | `organization` is the default: workspace name, plan, usage counts |
| `query_campaigns` | read | `action: list, get, variants, deployments, generation_status, share_links, dooh_status, dooh_analytics, manifest, get_component, forecast, list_templates, get_template, market_copy` | `list` pages with `cursor`; `get` accepts `include: [variants, products, targeting, experiments, generatedContent]`; `get_component` returns the campaign's custom Squid designs, which design each variant runs, preview URLs, permissions and the design guide. `forecast` and the template reads: see below |
| `manage_campaigns` | write | `action: create, update, delete, create_variant, update_variant, delete_variant, publish, deploy, update_deployment, duplicate, create_share_link, revoke_share_link, generate_playbook, create_component, publish_component, revert_component, check_component, match_templates, apply_template, approve_market_copy, approve_for_social` | See below. `check_component` and `match_templates` change no campaign data but use a daily workspace allowance |
| `generate_campaign` | write, credits | `mode: start` (needs `intent`), `mode: regenerate` (needs `campaignId`, `fromStep`) | Async. Poll `query_campaigns` `generation_status`. The credits for the campaign's AI images are set aside when the call is accepted, in both modes; when the workspace has too few, nothing starts and the answer is `precondition_failed` with `details.imageCount`, `creditsNeeded`, `creditsRemaining` and a remedy (generate with `options.includeImages: false`, retry later, or ask the workspace admin). Over campaign quota: `precondition_failed` |
| `query_products` | read | `action: list, get, import_status` | `get` returns `images[]` with `id`, `url`, `role`, `position` (primary first); `list` does not |
| `manage_products` | write | `action: create, import_from_url, update, delete, import_csv, add_image, remove_image, set_primary_image, reorder_images` | See below |
| `upload_asset` | write, free | `action: from_url` (`url`), `from_data` (`data` as base64 or a data URI, 1 MB max, optional `filename`), `create_upload` (`filename`, `bytes`, optional `mimeType`), `complete_upload` (`uploadId`) | Stores an image or video in the workspace and returns `asset.assetId` and `asset.url`. Optional `kind` (image or video) refuses a file of the other kind. Images JPEG, PNG, WebP, GIF, AVIF up to 16 MB; video MP4, MOV, WebM up to 64 MB by link, 128 MB through `create_upload`. HEIC, SVG, PDF and web pages are refused with a hint. The same file sent again returns the stored asset with `reused: true`. See below |
| `query_assets` | read | `action: list` (optional `kind`, `limit` 1 to 100, `cursor`), `get` (`assetId`) | The workspace's stored images and video, newest first: uploads, dashboard files and copied links. Each has `assetId`, `url`, `kind`, `mimeType`, `bytes`, `createdAt` |
| `query_surfaces` | read | `operation: list_surfaces, get_surface, list_zones` | Supplies `surfaceId` and `zoneId` for `deploy` |
| `manage_surfaces` | write, quota | `operation: create_surface, create_zone` | Editor role. `create_surface` takes `name`, `surfaceType` (web, vending, retail, transit, stadium, mall, outdoor_billboard, indoor_display, point_of_sale, lobby, speaker, ar, other), address fields, optional `zoneId`. `create_zone` takes `name`, `strategy` (priority-only, round-robin, weighted, zone-coordinated) |
| `query_brand` | read | `action: get, get_page, get_site, check_page` | `get`: brand book, profile, voice, concierge. `get_page`: the brand home page, the newest 20 stored versions with preview URLs, and the authoring guide; with `pageId` also that version's `index.html` (or the text file at `path`), its `sha256`, `byteSize` and `totalLines`, and `lines: {from, to}` returns part of it. `get_site` (`pageId`): the version's files with path, content type, size and `sha256`, no contents. `check_page`: checks a version (`pageId`, every file) or one document (`html`) against the guide's rules; with `pageId` it also returns the latest render check. Blocking findings stop a publish |
| `manage_brand` | write | `action: update_brandbook, update_profile, update_voice, update_concierge, set_logo, create_page, edit_page, create_version, put_files, create_file_upload, delete_files, publish_page, revert_page, delete_page, render_check` | Annotated destructive and not idempotent, so some hosts ask before every call. Roles and plan: see below. Each brand data subtree you send replaces the stored one; subtrees you omit are kept. `set_logo` takes `logoSlot` (primary default, light, dark, icon) and exactly one of `logoAssetId`, `logoUrl`; a link is copied into the workspace, SVG is refused |
| `query_analytics` | read | `action: snapshot, export, ab_test, cvg_dashboard, insights` | `snapshot` needs `startDate`, `endDate`; `sections` default `["summary"]`, others timeseries, funnel, cohorts, abTests, insights, products, breakdowns, spend (plan gated; fails the whole call without it), video, live, creatives (`creativesLimit` 1 to 200, default 50), siteActivity (`siteActivityBreakdown: {kind, property, limit?}` for one property's values). `export` takes `includeCreatives`. Window caps: hourly 14 days, daily 366. See below |
| `query_video` | read | `action: templates, progress, renders` | `templates` with `templateId` (logo-reveal, kinetic-promo, lightscribe) expands its props. `progress` takes one of: `campaignVideoRenderId`; `renderId` plus `bucketName`; `campaignId` plus `variantId` (Squid design exports) |
| `render_video` | write, daily limit | `mode: video, campaign, still, squid` | `video`, `campaign` and `still` render within a daily per-workspace limit; `squid` is recorded in a sandbox. See below |
| `query_social_schedules` | read | `action: accounts, list, get` | `accounts`: the connected Facebook Page, Instagram and Bluesky accounts with the `connectionId` a schedule's `channels` take, and the schedule limits. `list` and `get`: schedules with their posts and each post's status. See "Social post schedules" below |
| `manage_social_schedule` | write | `action: create, add_posts, update_post, skip_post, stop, approve, retry_post` | Annotated destructive. An agent proposes a schedule; nothing is posted until a person approves it. From this connection `approve`, `retry_post` and changing an approved post answer `approval_required` unless the workspace allows outside agents to approve. See "Social post schedules" below |

## manage_campaigns

| Action | Needs | Notes |
|---|---|---|
| `create` | `name`, `goal`, and `conversation` or `autoSetup: true` | A campaign without AI generation and with no variants yet. The chat must be set up: `conversation` sets it yourself, `autoSetup: true` has the platform write it at activation (one model call). Without either the answer is `invalid_input` naming `conversation`. Use `generate_campaign` for AI generation |
| `update` | `campaignId` | Also takes `conversation`, `shape` (`v1` or `v2`) and `autoSetup: true` (sets up now). `status: "active"` needs at least one variant and, at first launch, a set-up chat: otherwise `precondition_failed` with `details.missing` and a remedy, unless `autoSetup` was asked for. It publishes the web page if the campaign runs nowhere, and may return `approval: {status: "required"}` when the workspace wants a second approver |
| `create_variant`, `update_variant` | `campaignId` (+ `variantId`) | `contentStructure` is merged field by field; `isActive: false` retires reversibly. Saves on a live campaign republish. `contentStructure` image and video take `{assetId}` (from `upload_asset` or `query_assets`) or `{url}`; a link to another site is copied into the workspace |
| `delete`, `delete_variant` | ids | Permanent |
| `publish` | `campaignId` | `visibility: "public"` lets the edge serve the page publicly; omit it to leave the setting unchanged |
| `deploy` | `campaignId` and exactly one of `surfaceId`, `zoneId` | Optional `priority`, `isActive` |
| `update_deployment` | `deploymentId`, `status` | scheduled, active, paused, ended |
| `duplicate` | `campaignId` | Uses campaign quota |
| `create_share_link`, `revoke_share_link` | `campaignId` (+ `tokenId`) | Creating one makes the page private; the token is shown once |
| `generate_playbook` | `campaignId` | Writes the conversational playbook (opening, product facts, FAQs, chips) with paid inference |
| `create_component` | `campaignId`, `html`, `manifest` | A custom Squid design as one HTML document (512 KiB max). Stores a draft with a `previewUrl` (member). `publish: true` publishes at once (admin). `manifest.video` takes `durationMs` (3000 to 60000) and `viewport` (`"output"` or `{width, height}`, 320 to 1920 CSS px). `manifest.capabilities.chat` is `standard` (default, the campaign's chat bar over the design), `own` (the design's own ask field; `ask: true` is the older spelling) or `none`. `manifest.capabilities.live` is `inset` (default), `main`, `box` or `none`: where a routed live stream plays over the design. `manifest.capabilities.commentary` is `standard` (default), `own` or `none`: where live commentary shows |
| `publish_component` | `campaignId`, `componentId` | Admin. Adds a new variant carrying the design, optionally copying copy from `copyFromVariantId`, named `variantName` |
| `revert_component` | `campaignId`, `componentId` | Admin. Pauses the variants carrying the design |
| `check_component` | `componentId`, optional `campaignId`, `variantId` | Member role and a plan that includes custom designs. Changes no campaign data. Static checks of the stored design run at once and cost nothing. Where browser checks are switched on, it also starts a browser check at five sizes in a sandbox (20 design checks per workspace per UTC day) that finishes in a minute or two; call again until `browserCheck.status` is `done`, then open every `screenshotUrl`. A repeat for the same design and slot values returns the stored check. While browser checks are off, `browserCheck.status` is `not_run` with the reason, and the static findings still come back. Every finding is a warning; nothing blocks `publish_component` |
| `match_templates` | `campaignId`, optional `mode` (best or cast), `limit` (default 6, max 50) | Member. Changes no campaign data. The templates that suit the campaign's business, with reasons and a preview link each. May make a model call (30 uncached matches per workspace per UTC day, a match is kept for 7 days); without the model it ranks by words and says so in `fallbackReason` |
| `apply_template` | `campaignId`, `templateId` | Uses a template from the Squid template library as the campaign's design, baked with the brand book. Without `publish` it stores a draft design (member). `publish: true` adds it as a new variant at once (admin), with `copyFromVariantId`, `variantName` and `slotValues` (only with `publish: true`). The answer lists `filledSlots`, `emptyClaimSlots` (price, offer, dates and other claims with no value; they show empty until set with `update_variant` `contentStructure.squidSlots`) and a `summary` of what to do next |

| `approve_market_copy` | `campaignId`, `operation`, `market` | Editor or admin. Per-market copy approval (see "Market approval" below). `set_mode` needs `marketMode`; `approve`, `edit` and `lock` need `variantId` or `pendingId`; `edit` needs `copy` or `labels`. `labels` (`suggestedQuestions`, one per source chip in order; `inputPlaceholder`; `ctaLabel`) are the chat labels approved with the copy. A person may approve copy someone else wrote. Text that drops a kept glossary term is saved, and the answer's `warnings` say which |
| `approve_for_social` | `campaignId`, `variantIds` (1 to 20), optional `approved` (default true), `note`, `propose` | Member. Sets or clears the "Approved for socials" mark on the versions named, in one call. A marked version is one the workspace's own agent may post to social on its own. Refused, with nothing changed, when a version named is switched off or archived. A version that already has the mark is left as it is. The answer has `socialApproval.versions` (each version named, with `approvedForSocials` and `changed`) and `socialApproval.campaignVersions` (every version that is on, with `pictureUrl` and its mark as it is now). With `propose: true` nothing is written and `variantIds` may be empty: the answer lists every version that is on (`versions`, each with `pictureUrl`, `approvedForSocials` and `picked`), and hosts that draw cards show the person a picker with the picked versions ticked. Their press on Approve in that card sets the mark; it is the one card that saves. The mark changes nothing a visitor or a place shows |

Custom slot values for a design go in `update_variant` `contentStructure.squidSlots` (`{slotName: value}`); sending `squidSlots` replaces the whole object.

### Setting up the chat on a campaign made with `create`

A generated campaign comes with its chat set up. A campaign made with `create` gets it one of two ways:

- `conversation: {enabled: true, inputPlaceholder, suggestedQuestions, productFacts or faqs, toggleLabel?, openingMessage?, look?}`: chat on with your words. The card's answers are turned on. Free.
- `look` sets the copy card's colours: `neutral` (white card, near-black ink, no brand colours) or a dashboard Look built from the brand colours: `brand`, `dusk`, `paper`, `neon`, `gallery`, `ember`, `tide`. Every one passes the text contrast check. The brand colours (`query_brand` `action: get`) are there to inform the choice, not to force it: pick what reads well over the variant's photo and with its copy. Without `look`, a card with no colours gets the most readable option; with `autoSetup`, the playbook model picks.
- `autoSetup: true`: the platform writes the playbook, question chips and question box text from the campaign, its products and variants at activation (on `update`, at once). One model call; it may rewrite chat words you set.
- `conversation: {enabled: false}`: no chat. The page runs the standard design, and custom designs and templates are refused until chat is on.

At first activation, `details.missing` lists what is still missing: `chat_not_set`, `playbook_missing`, `questions_missing`, `placeholder_missing`, `variant_copy_missing` (the first variant has no headline and body). The variant needs a `contentStructure` `headline` and `body` for the copy card.

### Market approval

A market is one or more languages (`["fr"]`, `["fr-CA"]`), optionally narrowed to countries (`["CA"]`); a view's market is the most specific match. Each market has a mode:

- `live` (the default for every market): viewers get copy adapted for each view.
- `locked`: viewers get the version approved for the variant, or the variant's source copy when none is current. No model writes copy, chat labels or `/c/` language pages for them.
- `approve_first`: viewers get what `locked` gives. Their views are queued for review; the adapted copy is written when the queue is read (`query_campaigns` `market_copy`), and `pending` lists it. An item with `state: "writing"` has no copy yet: read `market_copy` again in about a minute. Approve a `ready` item with `approve_market_copy` and its `pendingId` (`edit` with `copy` to change it first, `lock` to also lock the market).

Chat labels (the suggested questions, the question box text and the chat button) are approved with the copy. Without `labels`, an approval stores the current approved labels, else a draft in the market's first language (written once by the label translation), else the source labels; `market_copy` shows them in `versions[].labels` and the source in `variants[].sourceLabels`, and a pending version carries the labels drafted for its language. A held market never shows labels a model wrote for its viewers.

An approval goes stale when someone edits the variant's copy: it is not served, the market shows the source copy, and `market_copy` marks it `stale` until it is approved again (`operation: approve`). Approved labels go stale the same way when the source labels change. Approved copy is stored copy and never carries the adaptation mark. Legal lines are separate and show in every mode.

## query_campaigns: forecast and template reads

| Action | Needs | Notes |
|---|---|---|
| `forecast` | `campaignId`, optional `surfaceTypes` | Predicted response rate of each active variant by surface type and daypart, with the top three reasons per variant in plain words. No credit spend. `available: false` with a reason when no model is active |
| `list_templates` | optional `query`, `limit`, `cursor` | Any role. Browses the Squid template library (title, vertical, what it suits, how calm or spectacular and how serious or playful, custom slots). No model call, no preview links |
| `get_template` | `templateId`, optional `campaignId` | Member. One template; with `campaignId` also a preview link and `starter`, the template baked with the brand as a starting point for your own `create_component` |

The template library is switched off on some deployments. Then every template action, including `manage_campaigns` `match_templates` and `apply_template`, answers `not_configured` ("the squid template library is not enabled for this server"). Say that templates are not available yet and offer a custom design instead; it is not an error to retry.

## manage_products

| Action | Needs | Notes |
|---|---|---|
| `create` | `name` | Optional `description`, `price`, `currency`, `sku`, `websiteUrl`, `category`, `tags`, `status`, one of `imageUrl` or `imageAssetId`. Uses product quota |
| `import_from_url` | `websiteUrl` | Reaches the open web and runs paid inference. The page's product image is copied into the workspace; a failed image copy does not fail the import. A site that refuses returns `upstream_error` with `details.reason` |
| `update` | `productId` | `price: null` clears the price. A new `imageUrl` or `imageAssetId` replaces the primary image and keeps the rest of the gallery |
| `delete` | `productId` | Permanent |
| `import_csv` | one of `csvContent` (2 MB, 10,000 rows) or `csvUrl` | Async; poll `query_products` `import_status`. Rows with a known `sku` update that product, others create one. `image_url` is downloaded and stored in the workspace; a failed download writes the row without the image and `warnings[]` says why |
| `add_image` | `productId`, one of `imageUrl`, `imageAssetId` | Optional `makePrimary`. Five images at most (`PRODUCT_IMAGE_LIMIT`) |
| `remove_image`, `set_primary_image` | `productId`, `imageId` | `imageId` from `query_products` `get` |
| `reorder_images` | `productId`, `imageIds` | Every gallery id exactly once |

Duplicates: `create` and `import_from_url` check for an existing product (by SKU or URL, else by name) and answer `precondition_failed` with `details.code: PRODUCT_EXISTS` and `details.matches`. Ask the user: use the existing product (its id) or add a new one (retry with `allowDuplicate: true`).

Image links: a link on another website is downloaded and stored in the workspace; if the download fails the call fails, the link is never saved as-is. Links already on SparkleTree or Shopify storage are kept.

## Brand pages and brand sites

| Action | Role | Notes |
|---|---|---|
| `create_page` | member draft, admin with `publish: true` | One complete HTML document (1 MiB). The answer carries the check result, the `sha256` and a preview URL |
| `edit_page` | member draft, admin with `publish: true` | `pageId`, `edits: [{old, new, replaceAll?}]` (1 to 50, exact text, applied in order), optional `path` (default `index.html`) and `expectedSha256` from `get_page`. A draft changes in place; a published version stays and the result becomes a new draft (`createdNewVersion`). A stale `expectedSha256` saves nothing and returns the current one |
| `create_version` | member | A draft copy of `basePageId` with all its files (default: the published version) |
| `put_files` | member | `pageId` and 1 to 20 `files`, each `{path, content}` for text (256 KiB, `index.html` 1 MiB), `contentBase64` (1 MiB decoded per file, 4 MiB per call), `siteAssetId` or `assetId` (from `upload_asset`). A version holds 200 files and 25 MiB. Only a draft without a link-preview recording can change |
| `create_file_upload` | member | `path`, `bytes` (10 MiB max). Returns `uploadUrl`, the `PUT` headers, `expiresAt` and a `siteAssetId` for `put_files` |
| `delete_files` | member | `pageId`, `paths`; `index.html` stays |
| `publish_page` | admin | Refused while the version has blocking check findings |
| `revert_page` | admin | Puts the default brand home page back |
| `delete_page` | admin | Permanently deletes a version that is not live |
| `render_check` | member | Loads every page of a version (8 HTML pages at most) on the brand host at 390x844 and 1280x800 in a sandbox and reports console errors, failed requests, layout shift, overflow, blank renders and slow loads, with screenshots. 20 per workspace per UTC day. Warnings only; read the result with `query_brand` `check_page` |

Brand data writes (`update_*`, `set_logo`) need the admin role; a workspace API key counts as a member and cannot make them. Plan: every brand page and brand site action needs a plan that includes publishing a brand page (not Starter); brand data writes are refused without an active plan, and on Starter when the workspace holds a verified address. The `forbidden` answer says which.

## query_analytics

Headline `impressions`, `clicks` and `conversions` in `summary` and `timeseries` include Meta Ads at day, week and month granularity, with a `channels` split (`sparkletree`, `meta`). Hourly granularity and the `productIds`, `storeIds` and `eventTypes` filters leave Meta out; `summary.meta` says whether Meta is included and why not, and carries Meta reach. `summary.totals.reach` is SparkleTree reach (sessions); Meta reach is never added to it.

`creatives` treats the creative (variant or Squid design) as the unit: `creatives.channels` is the overview by channel (signage, web, brand_pages, socials with platforms under it, qr_scans), each with its own rates and where the figure comes from ("Measured by SparkleTree" or "Reported by Meta"); `creatives.creatives.rows` lists each creative with per-channel figures, and `unattributed` holds figures not linked to a creative, one row per channel. `productIds`, `eventTypes` and segment filters make the section unavailable.

`siteActivity` is the dashboard's Site activity panel: what people do on the workspace's own sites. `siteActivity.kinds` lists each kind of event (`key` as `source:eventType:name`, `label`, `source` sdk, brand_page or embed, `site`, `count`, `sessions`, `properties`, `zeroResultCount`), at most 50 kinds and 30 properties each; `pages` lists brand page views by path and `pageSources` by traffic source. `siteActivityBreakdown: {kind, property, limit?}` (limit 1 to 100, default 20) adds `siteActivity.breakdown`, one property's values with `count` and `sessions`; a malformed `kind` answers `invalid_input`. Whole UTC days, up to 366 days back; `campaignIds`, `productIds`, `storeIds` and `eventTypes` make it `available: false`. How a site sends those events: the `surfaces-and-embed` skill, `references/site-activity.md`.

`spend` shows Meta spend in the ad account's currency (`currency.meta`) and never adds across currencies: `spendCents.meta`, `total`, `roas` and `cpa` are null when they would, and `spendByCurrency` always has the per-currency figures.

## upload_asset

| Action | Needs | Notes |
|---|---|---|
| `from_url` | `url` | A direct link to the file. The server downloads it (images 16 MB, video 64 MB) |
| `from_data` | `data` | Base64 or a data URI, 1 MB max. The file passes through the model's context, so keep it small |
| `create_upload` | `filename`, `bytes` (exact size) | For a local file over 1 MB or a large video (128 MB). Returns `upload.uploadUrl`, `upload.uploadId`, `expiresAt` and a ready curl line. PUT the file to `uploadUrl` as multipart form field `file` with the headers given, before `expiresAt` |
| `complete_upload` | `uploadId` | After the PUT. Checks the stored file and returns the asset |

Pass the `assetId` to the field that takes one: `manage_products` `imageAssetId` (create, update, add_image), `manage_brand` `set_logo` `logoAssetId`, `manage_campaigns` `create_variant` or `update_variant` `contentStructure` image or video `{assetId}`. Viewers cannot upload.

## render_video

| Mode | Needs | Notes |
|---|---|---|
| `still` | `templateId`, `props`, optional `atSeconds` | One frame. The cheap iteration |
| `video` | `templateId`, `props`, `quality` (draft or final) | Returns `renderId` and `bucketName`. 50 ad hoc renders per workspace per day |
| `campaign` | `campaignId`, optional `variantId`, `aspect` (16:9, 9:16, 1:1), `quality` | Without `variantId`, up to four active variants. Returns `campaignVideoRenderId` per variant |
| `squid` | `campaignId`, `variantId`, optional `formats` (9:16, 4:5, 1:1, 16:9), `durationS` (3 to 60) | Records a variant that runs a published custom design in a sandbox, not on the template renderer. 20 runs per workspace per day. A Starter workspace or one without an active plan gets `forbidden`; `upstream_error` means the plan lookup failed and nothing was queued. Poll `query_video` `progress` with `campaignId` and `variantId`; results are `squidExports[]`. Off on some deployments (`precondition_failed`, "not available") |

## Social post schedules

Posting schedules for a Facebook Page, Instagram and Bluesky. An agent on this connection proposes a schedule; a person approves it in SparkleTree. One plan is one schedule: several posts a day go in `timesOfDay`, and posts that differ per account or come later go in the same schedule with `add_posts`. Create a new schedule only for a separate plan.

`query_social_schedules`:

| Action | Needs | Notes |
|---|---|---|
| `accounts` | nothing | Each connected account: `platform` (`facebook_page`, `instagram`, `bluesky`), `connectionId`, `name`, `handle` (null for a Facebook Page), `active`, and `canPost` (active and allowed to post now). A Facebook Page and its linked Instagram account share one `connectionId`. Also `limits`: `postsPerAccountPerDay`, `timesPerDay`, `scheduleDays`, and `outsideAgentsMayApprove`: whether this workspace lets agents on an outside connection approve schedules, send posts again and change approved posts (off by default). Use accounts with `canPost: true` |
| `list` | nothing | Open schedules, newest first. `includeClosed: true` adds stopped and finished ones; `campaignId` narrows to one campaign |
| `get` | `scheduleId` | One schedule with every post |

A schedule carries `status` (`proposed`, `approved`, `stopped`, `finished`), `timeZone`, `revision`, `firstPostLocalTime` and `waitingForApproval` (drafts still ahead). Each post carries `localTime` (the owner's local time, ready to repeat as given), `platform`, `status`, its text and media, `campaignId`, `variantId` and `lastError`. Post statuses: `draft` (waits for approval), `scheduled` (approved, waits for its time), `publishing`, `published`, `failed`, `outcome_unknown` (the platform never answered; nothing retries it without the owner), `skipped`, `cancelled`.

`manage_social_schedule`:

| Action | Needs | Notes |
|---|---|---|
| `create` | `channels`, `posts`, and either `startInMinutes` or `rule` (`once`, `daily`, `weekly`) with `timeOfDay` or `timesOfDay` | Any role but viewer. `channels` is `[{platform, connectionId}]` from `accounts`; every post goes to each account. Optional `title` (120 characters), `campaignId`, `weekdays` (weekly; 0 is Sunday, 6 is Saturday), `startsOn` (`YYYY-MM-DD`, local; default tomorrow), `occurrences` (dates; default 1), `timeZone` (IANA, for example `America/Chicago`; default the zone of the workspace's places; with neither, ask the person, since the call is refused unless it uses `startInMinutes`). Times are local `HH:MM`, 24-hour. `startInMinutes` places one post that many minutes from now. Writes every post now as a draft and returns a proposed schedule: nothing is posted. The same create sent again within a few minutes returns the first schedule with `alreadyCreated: true` |
| `add_posts` | `scheduleId`, `posts`, and the same timing as `create` | Any role but viewer. Optional `channels` (default the schedule's own accounts). Times are in the schedule's time zone. On an approved schedule the added posts wait for approval and the approved posts keep going out. `alreadyAdded: true` means the same posts were there already |
| `update_post` | `postId` | Any role but viewer. Changes `message`, `imageUrl`, `imageAlt`, `videoUrl`, `link`, `localDate` or `timeOfDay` of one post. `removeMedia: true` takes its picture or video off (not on Instagram, which needs one). From this connection only a post that waits for approval can change, unless `outsideAgentsMayApprove` is true; otherwise an approved post answers `approval_required` |
| `skip_post` | `postId` | Any role but viewer. Holds one post back |
| `stop` | `scheduleId` | Cancels the posts not yet out. `draftsOnly: true` cancels only the posts that wait for approval |
| `approve` | `scheduleId`, optional `revision` | Editor or above. Makes the schedule's posts go out at their times. From this connection it answers `approval_required` unless `outsideAgentsMayApprove` is true (see below). `revision` from the last read refuses the approve when the schedule changed since |
| `retry_post` | `postId`, optional `confirmedNotPosted` | Editor or above. Sends a `failed` or `outcome_unknown` post again; for `outcome_unknown` a person first checks the account. From this connection it answers `approval_required` unless `outsideAgentsMayApprove` is true |

`onlyWhileProposed: true` on `update_post`, `skip_post` and `stop` refuses the change once the schedule is approved.

Each post in `posts`: `message` (2,200 characters at most; 300 on Bluesky; the caption on Instagram), and at most one of `imageUrl`, `videoUrl` or `designMedia`, plus optional `imageAlt` (Bluesky needs it), `link` (Facebook text posts only), `campaignId` and `variantId`. Fewer posts than places repeat in turn; posts are placed date by date, and on each date time by time. Instagram posts need an image or a video. Always pass `variantId` when a post comes from a version: the post is tied to that version and checked against it, and a version that is switched off is refused.

Media on a post:

- The version's own picture or video: `imageUrl` or `videoUrl` from `query_campaigns` `action: variants`. For a version with a custom design, a picture given while a recording of the design is ready is replaced by the design's still (`mediaReplaced` in the answer); write `imageAlt` for the still.
- A file of the owner's: store it with `upload_asset` and pass its `asset.url` as `imageUrl` or `videoUrl` (MP4). Bluesky takes video up to 100 MB and 3 minutes; a video it cannot take is refused at `create` with the reason.
- The version's design video or still: `designMedia: {kind: "video" or "still", exportIds?}` with `variantId`. The recordings come from `render_video` `mode: squid` (a sandbox allowance; confirm first). Each account gets the format it shows best: Facebook Page 4:5, Instagram 9:16 as a Reel, Bluesky 4:5. A recording still being made is fine: the post gets its file when it is ready. A post whose file is not ready at its time is held, never sent with something else, and the owner is told. Refused when the version has no recording ready or being made.

The answer to `create` and `add_posts` says what each post shows (`draftMedia`, `posts[].media`: design video, design still, or the version's own picture) and how many different pictures each platform's posts show (`pictures`). Tell the person both.

Limits: at most 3 scheduled posts per account per day, at most 3 times a day in `timesOfDay`, and a schedule spans at most 90 days. Over a limit the answer is `precondition_failed`.

Approval: a person approves on the Agent page under Scheduled posts (`/dashboard/agent`), or in the phone app under Florence, Scheduled posts. From this connection, `approve`, `retry_post` and `update_post` on an approved post answer `approval_required` and change nothing, unless the workspace allows outside agents to do them. A workspace admin allows it on the Agent page, under Florence actions, with the switch "Outside agents approve posts". It is off by default and separate from Florence's own mode and switches; `accounts` reports it as `outsideAgentsMayApprove`. When it is true, call `approve` only after the person has said yes in the conversation to that exact schedule, with its dates, times, accounts and posts shown first. When it is false, do not call `approve` and do not retry; say where the person approves, and name the switch only if the person asks how to let the agent approve. Never suggest turning it on unprompted. Once approved, each post goes out at its time, within 5 minutes, with no further step.

Other answers: `not_found` for a schedule or post outside the workspace; `forbidden` for a viewer, or a role below editor on `approve` and `retry_post`; `precondition_failed` when a limit is reached, an account is not connected, or the schedule changed or is closed (`details.code` says which).

## The generate_campaign intent

```json
{
  "mode": "start",
  "intent": {
    "objective": "increase_sales | drive_traffic | build_awareness | promote_event",
    "products": [{ "id": "<uuid if known>", "query": "product name", "confidence": 0.9 }],
    "context": {
      "timeConstraints": [{ "dayParts": ["evening"], "daysOfWeek": ["friday", "saturday"] }],
      "locationConstraints": [{ "type": "city", "value": "Stockholm" }],
      "audienceSegments": [{ "type": "behavioral", "value": "weekend brunch regulars" }]
    },
    "urgency": "immediate | scheduled | ongoing",
    "expectedOutcome": "one sentence, measurable",
    "successMetrics": ["bookings", "CTR (sessions)"]
  },
  "options": {
    "brandGuidelines": { "voice": "", "tone": "", "messagingRules": "" },
    "includeImages": true,
    "variantCount": 3,
    "generateConversationPlaybook": true
  }
}
```

At least one product must resolve; list products first with `query_products` `action: list`. `variantCount` is 1 to 10.

## Resources and prompts

Resources: `mosaic://capabilities` (tools, prompts and the recommended call order for product images, manual and AI campaigns, the brand page, brand sites, Squid designs, Squid templates and social post schedules), `mosaic://brand-page-guide`, `mosaic://campaigns/{id}/squid-component-guide` (the same guide `get_component` returns), `mosaic://org/{id}`, `mosaic://org/{id}/brand-guidelines`, `mosaic://campaigns/{id}`, `mosaic://products/{id}`, `mosaic://surfaces/{id}`, and `ui://mosaic/campaign-inspector@2`, the campaign inspector that hosts with MCP Apps render for `query_campaigns` and `generate_campaign`.

Prompts on the default profile: `campaign_brief` (titled Create Campaign Plan; goal, brandName, targetAudience, budget), `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `platform_onboarding`. The prompt list in `mosaic://capabilities` names exactly the prompts the connection's profile serves.

## Roles

Viewer: reads only; every write tool refuses it (including `manage_campaigns` `check_component` and `match_templates`), and so does `query_campaigns` `get_template`. Member: create, edit and publish campaigns, create products, upload assets, draft brand pages, brand site files and Squid designs, apply a template as a draft, run design and render checks. Editor: member plus surfaces, zones and deleting products. Admin: everything, including brand data writes, publishing, reverting and deleting brand pages, and publishing Squid designs and templates. A workspace API key counts as a member. A call outside the role returns `forbidden` with a remedy naming who can do it.

## Idempotency

Sending an `Idempotency-Key` HTTP header makes creates and quota reservations safe to retry: a replay returns the first result. `manage_campaigns` `duplicate` also takes `idempotencyKey` as a field.
