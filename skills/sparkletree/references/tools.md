# The default tool surface

Seventeen tools on the bare URL (`external_default`). Reads and writes never share a tool. Every tool takes one flat input with a discriminator (`action`, `mode`, `operation` or `topic`); the handler checks the fields for that action and answers `invalid_input` naming the bad ones. `organizationId` is optional everywhere and comes from the sign-in. Verified against the server source on 2026-10-15 (monorepo main 4be3e1bed, plus the final 1.0.3 change that moved `check_component` and `match_templates` to `manage_campaigns`).

| Tool | Read or write | Actions | Notes |
|---|---|---|---|
| `get_platform_info` | read | `topic: health, organization, tool_profiles` | `organization` is the default: workspace name, plan, usage counts |
| `query_campaigns` | read | `action: list, get, variants, deployments, generation_status, share_links, dooh_status, dooh_analytics, manifest, get_component, forecast, list_templates, get_template` | `list` pages with `cursor`; `get` accepts `include: [variants, products, targeting, experiments, generatedContent]`; `get_component` returns the campaign's custom Squid designs, which design each variant runs, preview URLs, permissions and the design guide. `forecast` and the template reads: see below |
| `manage_campaigns` | write | `action: create, update, delete, create_variant, update_variant, delete_variant, publish, deploy, update_deployment, duplicate, create_share_link, revoke_share_link, generate_playbook, create_component, publish_component, revert_component, check_component, match_templates, apply_template` | See below. `check_component` and `match_templates` change no campaign data but use a daily workspace allowance |
| `generate_campaign` | write, credits | `mode: start` (needs `intent`), `mode: regenerate` (needs `campaignId`, `fromStep`) | Async. Poll `query_campaigns` `generation_status`. The credits for the campaign's AI images are set aside when the call is accepted, in both modes; when the workspace has too few, nothing starts and the answer is `precondition_failed` with `details.imageCount`, `creditsNeeded`, `creditsRemaining` and a remedy (generate with `options.includeImages: false`, retry later, or ask the workspace admin). Over campaign quota: `precondition_failed` |
| `query_products` | read | `action: list, get, import_status` | `get` returns `images[]` with `id`, `url`, `role`, `position` (primary first); `list` does not |
| `manage_products` | write | `action: create, import_from_url, update, delete, import_csv, add_image, remove_image, set_primary_image, reorder_images` | See below |
| `upload_asset` | write, free | `action: from_url` (`url`), `from_data` (`data` as base64 or a data URI, 1 MB max, optional `filename`), `create_upload` (`filename`, `bytes`, optional `mimeType`), `complete_upload` (`uploadId`) | Stores an image or video in the workspace and returns `asset.assetId` and `asset.url`. Optional `kind` (image or video) refuses a file of the other kind. Images JPEG, PNG, WebP, GIF, AVIF up to 16 MB; video MP4, MOV, WebM up to 64 MB by link, 128 MB through `create_upload`. HEIC, SVG, PDF and web pages are refused with a hint. The same file sent again returns the stored asset with `reused: true`. See below |
| `query_assets` | read | `action: list` (optional `kind`, `limit` 1 to 100, `cursor`), `get` (`assetId`) | The workspace's stored images and video, newest first: uploads, dashboard files and copied links. Each has `assetId`, `url`, `kind`, `mimeType`, `bytes`, `createdAt` |
| `query_surfaces` | read | `operation: list_surfaces, get_surface, list_zones` | Supplies `surfaceId` and `zoneId` for `deploy` |
| `manage_surfaces` | write, quota | `operation: create_surface, create_zone` | Editor role. `create_surface` takes `name`, `surfaceType` (web, vending, retail, transit, stadium, mall, outdoor_billboard, indoor_display, point_of_sale, lobby, speaker, ar, other), address fields, optional `zoneId`. `create_zone` takes `name`, `strategy` (priority-only, round-robin, weighted, zone-coordinated) |
| `query_brand` | read | `action: get, get_page, get_site, check_page` | `get`: brand book, profile, voice, concierge. `get_page`: the brand home page, the newest 20 stored versions with preview URLs, and the authoring guide; with `pageId` also that version's `index.html` (or the text file at `path`), its `sha256`, `byteSize` and `totalLines`, and `lines: {from, to}` returns part of it. `get_site` (`pageId`): the version's files with path, content type, size and `sha256`, no contents. `check_page`: checks a version (`pageId`, every file) or one document (`html`) against the guide's rules; with `pageId` it also returns the latest render check. Blocking findings stop a publish |
| `manage_brand` | write | `action: update_brandbook, update_profile, update_voice, update_concierge, set_logo, create_page, edit_page, create_version, put_files, create_file_upload, delete_files, publish_page, revert_page, delete_page, render_check` | Annotated destructive and not idempotent, so some hosts ask before every call. Roles and plan: see below. Each brand data subtree you send replaces the stored one; subtrees you omit are kept. `set_logo` takes `logoSlot` (primary default, light, dark, icon) and exactly one of `logoAssetId`, `logoUrl`; a link is copied into the workspace, SVG is refused |
| `query_analytics` | read | `action: snapshot, export, ab_test, cvg_dashboard, insights` | `snapshot` needs `startDate`, `endDate`; `sections` default `["summary"]`, others timeseries, funnel, cohorts, abTests, insights, products, breakdowns, spend (plan gated; fails the whole call without it), video, live, creatives (`creativesLimit` 1 to 200, default 50). `export` takes `includeCreatives`. Window caps: hourly 14 days, daily 366. See below |
| `query_video` | read | `action: templates, progress, renders` | `templates` with `templateId` (logo-reveal, kinetic-promo, lightscribe) expands its props. `progress` takes one of: `campaignVideoRenderId`; `renderId` plus `bucketName`; `campaignId` plus `variantId` (Squid design exports) |
| `render_video` | write, daily limit | `mode: video, campaign, still, squid` | `video`, `campaign` and `still` render within a daily per-workspace limit; `squid` is recorded in a sandbox. See below |
| `query_video_commissions` | read | `action: list, get` | Poll `get` until `proof_ready` or `delivered` |
| `video_commission` | write, daily limit | `action: create, approve, revise, cancel` | `create` takes `briefMd` (the description of the film), `aspects`, `targetDurationS` (max 30), optional `tier: marquee or atelier`. Five per workspace per day |

## manage_campaigns

| Action | Needs | Notes |
|---|---|---|
| `create` | `name`, `goal` | Empty shell: no AI, no variants, no playbook. Use `generate_campaign` for AI generation |
| `update` | `campaignId` | `status: "active"` needs at least one variant, writes a playbook if missing, publishes the web page if the campaign runs nowhere, and may return `approval: {status: "required"}` when the workspace wants a second approver |
| `create_variant`, `update_variant` | `campaignId` (+ `variantId`) | `contentStructure` is merged field by field; `isActive: false` retires reversibly. Saves on a live campaign republish. `contentStructure` image and video take `{assetId}` (from `upload_asset` or `query_assets`) or `{url}`; a link to another site is copied into the workspace |
| `delete`, `delete_variant` | ids | Permanent |
| `publish` | `campaignId` | `visibility: "public"` lets the edge serve the page publicly; omit it to leave the setting unchanged |
| `deploy` | `campaignId` and exactly one of `surfaceId`, `zoneId` | Optional `priority`, `isActive` |
| `update_deployment` | `deploymentId`, `status` | scheduled, active, paused, ended |
| `duplicate` | `campaignId` | Uses campaign quota |
| `create_share_link`, `revoke_share_link` | `campaignId` (+ `tokenId`) | Creating one makes the page private; the token is shown once |
| `generate_playbook` | `campaignId` | Writes the conversational playbook (opening, product facts, FAQs, chips) with paid inference |
| `create_component` | `campaignId`, `html`, `manifest` | A custom Squid design as one HTML document (512 KiB max). Stores a draft with a `previewUrl` (member). `publish: true` publishes at once (admin). `manifest.video` takes `durationMs` (3000 to 60000) and `viewport` (`"output"` or `{width, height}`, 320 to 1920 CSS px) |
| `publish_component` | `campaignId`, `componentId` | Admin. Adds a new variant carrying the design, optionally copying copy from `copyFromVariantId`, named `variantName` |
| `revert_component` | `campaignId`, `componentId` | Admin. Pauses the variants carrying the design |
| `check_component` | `componentId`, optional `campaignId`, `variantId` | Member role and a plan that includes custom designs. Changes no campaign data. Static checks of the stored design run at once and cost nothing. Where browser checks are switched on, it also starts a browser check at five sizes in a sandbox (20 design checks per workspace per UTC day) that finishes in a minute or two; call again until `browserCheck.status` is `done`, then open every `screenshotUrl`. A repeat for the same design and slot values returns the stored check. While browser checks are off, `browserCheck.status` is `not_run` with the reason, and the static findings still come back. Every finding is a warning; nothing blocks `publish_component` |
| `match_templates` | `campaignId`, optional `mode` (best or cast), `limit` (default 6, max 50) | Member. Changes no campaign data. The templates that suit the campaign's business, with reasons and a preview link each. May make a model call (30 uncached matches per workspace per UTC day, a match is kept for 7 days); without the model it ranks by words and says so in `fallbackReason` |
| `apply_template` | `campaignId`, `templateId` | Uses a template from the Squid template library as the campaign's design, baked with the brand book. Without `publish` it stores a draft design (member). `publish: true` adds it as a new variant at once (admin), with `copyFromVariantId`, `variantName` and `slotValues` (only with `publish: true`). The answer lists `filledSlots`, `emptyClaimSlots` (price, offer, dates and other claims with no value; they show empty until set with `update_variant` `contentStructure.squidSlots`) and a `summary` of what to do next |

Custom slot values for a design go in `update_variant` `contentStructure.squidSlots` (`{slotName: value}`); sending `squidSlots` replaces the whole object.

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

Site activity (brand page views by page path, and the events a brand page or an SDK site sends with `track`) is shown in the dashboard only; no `query_analytics` section returns it yet. How a site sends those events: the `surfaces-and-embed` skill, `references/site-activity.md`.

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

Resources: `mosaic://capabilities` (tools, prompts and the recommended call order for product images, manual and AI campaigns, the brand page, brand sites, Squid designs and Squid templates), `mosaic://brand-page-guide`, `mosaic://campaigns/{id}/squid-component-guide` (the same guide `get_component` returns), `mosaic://org/{id}`, `mosaic://org/{id}/brand-guidelines`, `mosaic://campaigns/{id}`, `mosaic://products/{id}`, `mosaic://surfaces/{id}`, and `ui://mosaic/campaign-inspector@2`, the campaign inspector that hosts with MCP Apps render for `query_campaigns` and `generate_campaign`.

Prompts on the default profile: `campaign_brief` (titled Create Campaign Plan; goal, brandName, targetAudience, budget), `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `platform_onboarding`. The prompt list in `mosaic://capabilities` names exactly the prompts the connection's profile serves.

## Roles

Viewer: reads only; every write tool refuses it (including `manage_campaigns` `check_component` and `match_templates`), and so does `query_campaigns` `get_template`. Member: create, edit and publish campaigns, create products, upload assets, draft brand pages, brand site files and Squid designs, apply a template as a draft, run design and render checks. Editor: member plus surfaces, zones and deleting products. Admin: everything, including brand data writes, publishing, reverting and deleting brand pages, and publishing Squid designs and templates. A workspace API key counts as a member. A call outside the role returns `forbidden` with a remedy naming who can do it.

## Idempotency

Sending an `Idempotency-Key` HTTP header makes creates and quota reservations safe to retry: a replay returns the first result. `manage_campaigns` `duplicate` also takes `idempotencyKey` as a field.
