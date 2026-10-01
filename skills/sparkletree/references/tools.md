# The default tool surface

Seventeen tools on the bare URL (`external_default`). Reads and writes never share a tool. Every tool takes one flat input with a discriminator (`action`, `mode`, `operation` or `topic`); the handler checks the fields for that action and answers `invalid_input` naming the bad ones. `organizationId` is optional everywhere and comes from the sign-in. Verified against the server source on 2026-10-01 (monorepo main b22d8254a).

| Tool | Read or write | Actions | Notes |
|---|---|---|---|
| `get_platform_info` | read | `topic: health, organization, tool_profiles` | `organization` is the default: workspace name, plan, usage counts |
| `query_campaigns` | read | `action: list, get, variants, deployments, generation_status, share_links, dooh_status, dooh_analytics, manifest, get_component` | `list` pages with `cursor`; `get` accepts `include: [variants, products, targeting, experiments, generatedContent]`; `get_component` returns the campaign's custom Squid designs, which design each variant runs, preview URLs, permissions and the design guide |
| `manage_campaigns` | write | `action: create, update, delete, create_variant, update_variant, delete_variant, publish, deploy, update_deployment, duplicate, create_share_link, revoke_share_link, generate_playbook, create_component, publish_component, revert_component` | See below |
| `generate_campaign` | write, credits | `mode: start` (needs `intent`), `mode: regenerate` (needs `campaignId`, `fromStep`) | Async. Poll `query_campaigns` `generation_status`. Over quota: `precondition_failed` |
| `query_products` | read | `action: list, get, import_status` | `get` returns `images[]` with `id`, `url`, `role`, `position` (primary first); `list` does not |
| `manage_products` | write | `action: create, import_from_url, update, delete, import_csv, add_image, remove_image, set_primary_image, reorder_images` | See below |
| `upload_asset` | write, free | `action: from_url` (`url`), `from_data` (`data` as base64 or a data URI, 1 MB max, optional `filename`), `create_upload` (`filename`, `bytes`, optional `mimeType`), `complete_upload` (`uploadId`) | Stores an image or video in the workspace and returns `asset.assetId` and `asset.url`. Optional `kind` (image or video) refuses a file of the other kind. Images JPEG, PNG, WebP, GIF, AVIF up to 16 MB; video MP4, MOV, WebM up to 64 MB by link, 128 MB through `create_upload`. HEIC, SVG, PDF and web pages are refused with a hint. The same file sent again returns the stored asset with `reused: true`. See below |
| `query_assets` | read | `action: list` (optional `kind`, `limit` 1 to 100, `cursor`), `get` (`assetId`) | The workspace's stored images and video, newest first: uploads, dashboard files and copied links. Each has `assetId`, `url`, `kind`, `mimeType`, `bytes`, `createdAt` |
| `query_surfaces` | read | `operation: list_surfaces, get_surface, list_zones` | Supplies `surfaceId` and `zoneId` for `deploy` |
| `manage_surfaces` | write, quota | `operation: create_surface, create_zone` | Editor role. `create_surface` takes `name`, `surfaceType` (web, vending, retail, transit, stadium, mall, outdoor_billboard, indoor_display, point_of_sale, lobby, speaker, ar, other), address fields, optional `zoneId`. `create_zone` takes `name`, `strategy` (priority-only, round-robin, weighted, zone-coordinated) |
| `query_brand` | read | `action: get, get_page` | `get`: brand book, profile, voice, concierge. `get_page`: the brand home page, every stored version with a preview URL, and the authoring guide |
| `manage_brand` | write | `action: update_brandbook, update_profile, update_voice, update_concierge, set_logo, create_page, publish_page, revert_page` | Admin role, except a `create_page` draft (member). Each subtree you send replaces the stored one; subtrees you omit are kept. `set_logo` takes `logoSlot` (primary default, light, dark, icon) and exactly one of `logoAssetId`, `logoUrl`; a link is copied into the workspace, SVG is refused. Plan: brand page actions need a plan that includes publishing a brand page (not Starter); brand data writes are refused without an active plan, and on Starter when the workspace holds a verified address |
| `query_analytics` | read | `action: snapshot, export, ab_test, cvg_dashboard, insights` | `snapshot` needs `startDate`, `endDate`; `sections` default `["summary"]`, others timeseries, funnel, cohorts, abTests, insights, products, breakdowns, spend (plan gated; fails the whole call without it), video, live. Window caps: hourly 14 days, daily 366 |
| `query_video` | read | `action: templates, progress, renders` | `templates` with `templateId` (logo-reveal, kinetic-promo, lightscribe) expands its props. `progress` takes one of: `campaignVideoRenderId`; `renderId` plus `bucketName`; `campaignId` plus `variantId` (Squid design exports) |
| `render_video` | write, credits | `mode: video, campaign, still, squid` | See below |
| `query_video_commissions` | read | `action: list, get` | Poll `get` until `proof_ready` or `delivered` |
| `video_commission` | write, credits, metered | `action: create, approve, revise, cancel` | `create` takes `briefMd` (the description of the film), `aspects`, `targetDurationS` (max 30), optional `tier: marquee or atelier`. Five per workspace per day |

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
| `create_component` | `campaignId`, `html`, `manifest` | A custom Squid design as one HTML document (512 KiB max). Stores a draft with a `previewUrl` (member). `publish: true` publishes at once (admin) |
| `publish_component` | `campaignId`, `componentId` | Admin. Adds a new variant carrying the design, optionally copying copy from `copyFromVariantId`, named `variantName` |
| `revert_component` | `campaignId`, `componentId` | Admin. Pauses the variants carrying the design |

Custom slot values for a design go in `update_variant` `contentStructure.squidSlots` (`{slotName: value}`); sending `squidSlots` replaces the whole object.

## manage_products

| Action | Needs | Notes |
|---|---|---|
| `create` | `name` | Optional `description`, `price`, `currency`, `sku`, `websiteUrl`, `category`, `tags`, `status`, one of `imageUrl` or `imageAssetId`. Uses product quota |
| `import_from_url` | `websiteUrl` | Reaches the open web and runs paid inference. The page's product image is copied into the workspace; a failed image copy does not fail the import. A site that refuses returns `upstream_error` with `details.reason` |
| `update` | `productId` | `price: null` clears the price. A new `imageUrl` or `imageAssetId` replaces the primary image and keeps the rest of the gallery |
| `delete` | `productId` | Permanent |
| `import_csv` | one of `csvContent` (2 MB) or `csvUrl` | Async; poll `query_products` `import_status` |
| `add_image` | `productId`, one of `imageUrl`, `imageAssetId` | Optional `makePrimary`. Five images at most (`PRODUCT_IMAGE_LIMIT`) |
| `remove_image`, `set_primary_image` | `productId`, `imageId` | `imageId` from `query_products` `get` |
| `reorder_images` | `productId`, `imageIds` | Every gallery id exactly once |

Duplicates: `create` and `import_from_url` check for an existing product (by SKU or URL, else by name) and answer `precondition_failed` with `details.code: PRODUCT_EXISTS` and `details.matches`. Ask the user: use the existing product (its id) or add a new one (retry with `allowDuplicate: true`).

Image links: a link on another website is downloaded and stored in the workspace; if the download fails the call fails, the link is never saved as-is. Links already on SparkleTree or Shopify storage are kept.

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
| `squid` | `campaignId`, `variantId`, optional `formats` (9:16, 4:5, 1:1, 16:9), `durationS` (3 to 60) | Records a variant that runs a published custom design. 20 runs per workspace per day. Poll `query_video` `progress` with `campaignId` and `variantId`; results are `squidExports[]`. Off on some deployments (`precondition_failed`, "not available") |

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

Resources: `mosaic://capabilities` (tools and recommended call order, including the three ways to get a product image in), `mosaic://brand-page-guide`, `mosaic://campaigns/{id}/squid-component-guide` (the same guide `get_component` returns), `mosaic://org/{id}`, `mosaic://org/{id}/brand-guidelines`, `mosaic://campaigns/{id}`, `mosaic://products/{id}`, `mosaic://surfaces/{id}`.

Prompts: `campaign_brief` (titled Create Campaign Plan; goal, brandName, targetAudience, budget), `analytics_deep_dive`, `surface_network_planner`, `content_optimizer`, `platform_onboarding`.

## Roles

Viewer: reads only; every write tool refuses it. Member: create, edit and publish campaigns, create products, upload assets, draft brand pages and Squid designs. Editor: member plus surfaces, zones and deleting products. Admin: everything, including brand writes and publishing brand pages and Squid designs. A workspace API key counts as a member. A call outside the role returns `forbidden` with a remedy naming who can do it.

## Idempotency

Sending an `Idempotency-Key` HTTP header makes creates and quota reservations safe to retry: a replay returns the first result. `manage_campaigns` `duplicate` also takes `idempotencyKey` as a field.
