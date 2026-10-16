---
name: surfaces-and-embed
description: SparkleTree campaign surfaces and embedding. Put a published campaign on a website, in a React or Next.js app, on screens, kiosks and signage, or behind a QR code. Covers the edge script tag, the React SDK (install, provider, Hero or Cta island, origin registration, track for Site activity), surfaces, zones and deploy. Use for embed, put it on my site, script tag, SDK, track clicks, signage, kiosk, screen, QR.
---

# Surfaces and embed

A campaign reaches people through surfaces. Pick the route by what the user has, then do the work in their repo or their workspace.

Read first: `query_campaigns` `action: list` (the campaign must be published for any of this to show anything) and `query_surfaces` `operation: list_surfaces` plus `list_zones`.

## Route table

| The user has | Route | What you do |
|---|---|---|
| Nothing yet | Brand page | Publish the campaign. It appears on `<slug>.sparkletree.io` with its own page. Done. |
| A web page they can add a script tag to | Edge script | One tag, see below. No build step. |
| A React or Next.js codebase (`react`, `next` or `@sparkletree/*` in package.json) | React SDK | Install, provider, island, origin. See `references/sdk-react.md`. |
| Paid traffic or a link in bio | Landing page | Every published campaign has a hosted `/lp/<org-slug>/<campaign-slug>` page; add UTM parameters. |
| Physical screens, kiosks, signage | Surfaces and zones | Create surfaces, group into a zone, deploy, publish. See `references/signage.md`. |
| Print or physical touchpoints | QR | Brand page QR is under Dashboard > Brand > Publishing; campaign and surface QR scans are tracked as clicks. |

## Edge script

```html
<script src="https://app.sparkletree.io/api/embed/v1/script.js?org=<org-slug>"></script>
```

The Squid renders in place, served from the edge, showing the variant Adaptive CVG currently prefers. Nothing to redeploy when the campaign changes. The old `/embed/[id]` route is deprecated; replace it with this tag. Get the org slug from `get_platform_info` `topic: "organization"`.

## React SDK, the short version

1. Detect: `package.json` has `next` or `react`. Confirm the package manager from the lockfile.
2. Install: `npm install @sparkletree/core @sparkletree/react` (or the pnpm/yarn equivalent). Alternatively `npx @sparkletree/cli add hero cta` copies the component source into the repo; do one or the other, not both.
3. Provider: one `SparkletreeProvider` per page view with `publishableKey` from the dashboard (`st_pk_test_...` locally, `st_pk_live_...` in production). The key is a signed credential minted in the dashboard and required on every request; it is visible in page source, so protection comes from the origin registry and rate limits.
4. Island: replace the real hero or CTA in the real component with `<Hero campaignId="..." fallback={{ headline: current, body: current }} />` or `<Cta campaignId="..." fallback={{ cta: current }} href="..." />`. `fallback` is required and must be the copy the page ships today; it is what a visitor reads if the network is slow or the campaign is paused.
5. Origin: live keys only work from an origin registered on the workspace, otherwise every request fails (`POST /api/organizations/{orgId}/embed-origins` with `{ "origin": "https://site" }`, or Settings in the dashboard). Localhost over plain http is not admitted for live keys; use a test key locally, it needs no registered origin.
6. Verify degrade first: point at an unreachable `apiBase`, load the page, confirm the fallback renders and `phase` is `failed`. Then verify the happy path.

Details, props, Next.js App Router notes and CSP lines: `references/sdk-react.md`.

## Site activity: record what visitors do

Impressions and clicks on campaign creative are recorded by the script tag and the SDK components, and brand page views by the edge. The site's own buttons, links and searches reach Dashboard > Analytics > Site activity only when the site sends them with the SDK's `track`: a `campaignId` of the workspace, `"click"` or `"custom"`, and every detail inside `context` with `context.kind` as the event's name. Ask the user which actions they want to see and wire them while building. Snippets, naming rules and how to read them back with `query_analytics` `siteActivity`: `references/site-activity.md`.

## Create a surface and deploy

Confirm before each write. Surfaces and zones need the editor role and use the workspace's surface quota.

1. `manage_surfaces` `operation: create_surface` with `name`, `surfaceType` (web, retail, indoor_display, transit, stadium, mall, outdoor_billboard, point_of_sale, lobby, vending, speaker, ar, other), and address, city, country when physical.
2. Optional: `manage_surfaces` `operation: create_zone` (`name`, `strategy`: priority-only, round-robin, weighted, zone-coordinated) and assign surfaces to it.
3. `manage_campaigns` `action: deploy` with `campaignId` and exactly one of `surfaceId` or `zoneId`, plus `priority`.
4. `manage_campaigns` `action: publish` if not yet published. Publish and deploy trigger republish; there is no separate flush step.

Report the surface id, the deployment, and where to see it.
