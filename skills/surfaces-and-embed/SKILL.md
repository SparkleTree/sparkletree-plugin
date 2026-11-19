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

Needs `@sparkletree/*` 0.16.0 or later for the setup commands below. The docs for the installed version are in the packages: `npx @sparkletree/cli docs` lists them, `npx @sparkletree/cli docs quickstart` prints one.

1. Detect: `package.json` has `next` or `react`. Confirm the package manager from the lockfile.
2. Install: `npm install @sparkletree/core @sparkletree/react` (or the pnpm/yarn equivalent).
3. Set up: `npx @sparkletree/cli init --origin https://their-site --json` registers the site, picks the campaign and writes the SparkleTree lines into `.env.local` (a test key for development; it prints the live key and the lines for production). It needs a sign-in first. Signing in is the user's step: ask them to run `npx @sparkletree/cli login` and approve it in the browser, or to set `SPARKLETREE_TOKEN`. Never approve a sign-in yourself. Without a sign-in `init --json` stops at once with `not_signed_in`. With more than one servable campaign it stops with `choose_campaign` and the list; rerun with `--campaign <id>`. `--dry-run` shows what it would write.
4. Provider: `npx @sparkletree/cli add provider hero cta` copies a provider written for the project's framework that reads exactly what `init` wrote, plus the components. One provider per page view. If the repo already has a provider copied by 0.15.0 or earlier, run `npx @sparkletree/cli upgrade`: that provider throws in the browser.
5. Island: replace the real hero or CTA in the real component with `<Hero campaignId="..." fallback={{ headline: current, body: current }} />` or `<Cta campaignId="..." fallback={{ cta: current }} href="..." />`. `fallback` is required and must be the copy the page ships today; it is what a visitor reads if the network is slow or the campaign is paused.
6. Check: `npx @sparkletree/cli doctor --url https://their-site/page --json` checks the key, the site's registration, the campaign, the page's content security policy and server rendering. Every `fail` and `warn` carries a `remedy`; act on it.
7. Verify degrade before the happy path: `npx @sparkletree/cli dev --failure offline` runs a local mock edge and prints the env lines to point at it; load the page and confirm the fallback renders. Then run it without `--failure`.

Without the CLI: Dashboard > Settings > Embedding shows the live key (`st_pk_live_...`) only, and a live key only works from a site registered there, never from localhost. For local work use a test key (`st_pk_test_...`). There are two ways to get one: `init` writes it into the env file, and `query_brand` `action: get_page` returns it as `devPublishableKey`. A test key works from a page on localhost and from a server; from any other site (a preview deployment, for example) the site must be registered too, or the browser cannot read the answers. On localhost the hero, CTA and live streams, facts, slots, questions and events work; new fragment copy is not written from localhost (fields show copy that is already warm, or their fallback), so test fresh fragment copy on a registered https site or against `npx @sparkletree/cli dev`. A key is visible in page source; protection comes from the registered sites and rate limits.

Not React (Astro, Svelte, Liquid, plain HTML): `@sparkletree/core/elements` gives the same behaviour as custom elements, with the served text as the fallback.

Details, props, facts and slots, tests, results, Next.js App Router notes and CSP lines: `references/sdk-react.md`.

## Site activity: record what visitors do

Impressions and clicks on campaign creative are recorded by the script tag and the SDK components, and brand page views by the edge. The site's own buttons, links and searches reach Dashboard > Analytics > Site activity only when the site sends them with the SDK's `track`: a `campaignId` of the workspace, `"click"` or `"custom"`, and every detail inside `context` with `context.kind` as the event's name. Ask the user which actions they want to see and wire them while building. Snippets, naming rules and how to read them back with `query_analytics` `siteActivity`: `references/site-activity.md`.

## Create a surface and deploy

Confirm before each write. Surfaces and zones need the editor role and use the workspace's surface quota.

1. `manage_surfaces` `operation: create_surface` with `name`, `surfaceType` (web, retail, indoor_display, transit, stadium, mall, outdoor_billboard, point_of_sale, lobby, vending, speaker, ar, other), and address, city, country when physical.
2. Optional: `manage_surfaces` `operation: create_zone` (`name`, `strategy`: priority-only, round-robin, weighted, zone-coordinated) and assign surfaces to it.
3. `manage_campaigns` `action: deploy` with `campaignId` and exactly one of `surfaceId` or `zoneId`, plus `priority`.
4. `manage_campaigns` `action: publish` if not yet published. Publish and deploy trigger republish; there is no separate flush step.

Report the surface id, the deployment, and where to see it.
