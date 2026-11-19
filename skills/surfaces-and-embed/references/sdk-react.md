# React SDK reference

Packages, 0.16.0 or later: `@sparkletree/core` (framework-agnostic; also `/elements` for custom elements, `/testing` for a mock edge, `/server` for server-side reads), `@sparkletree/react` (provider, hooks, components), `@sparkletree/cli` (setup and checks: `login`, `init`, `doctor`, `dev`, `results`, `docs`; and `add` / `upgrade` for component source copied into the repo in the shadcn style).

Read the docs for the installed version before writing code: `npx @sparkletree/cli docs --list`, then `npx @sparkletree/cli docs <topic>` (`quickstart`, `fragments`, `facts`, `elements`, `testing`, `setup-checks`, `cli`, ...). They ship inside the packages (`node_modules/@sparkletree/core/llms.txt` and `docs/`).

## Minimum integration

```tsx
import { SparkletreeProvider, Hero, Cta } from "@sparkletree/react";

// The live publishable key (a test key, st_pk_test_..., for local work). It ships to the browser and is visible in page source.
<SparkletreeProvider publishableKey="st_pk_live_...">
  <Hero
    campaignId="camp_123"
    fallback={{ headline: "Software that meets the moment", body: "Adaptive creative for the whole funnel." }}
  />
  <Cta campaignId="camp_123" fallback={{ cta: "Start free" }} href="/signup" />
</SparkletreeProvider>
```

Self-hosting can pass `apiBase` and `organizationId` explicitly, but `publishableKey` is still required: the server refuses to stream without one.

## Before the first request works

| Needed | Source |
|---|---|
| All of the below, in one step | `npx @sparkletree/cli init --origin https://site --json` after the user has signed in with `npx @sparkletree/cli login`. It writes the env file and registers the site |
| `publishableKey` | A test key for local work: `init` writes it, or `query_brand` `action: get_page` returns `devPublishableKey`. The live key: `init --origin` prints it, or Dashboard > Settings > Embedding (which shows the live key only). A signed credential, required on every request. `st_pk_test_...` works from a page on localhost and from a server (from any other site the origin must be registered as well); `st_pk_live_...` only works from a registered origin. Visible in page source, so protection is the origin registry plus rate limits; rotate from the dashboard if it leaks |
| `campaignId` | Dashboard, or `query_campaigns` `action: list`. `surfaceId` may be used instead when a surface decides what plays |
| Allowed origin | Register the site origin per workspace (`init --origin`); wildcards rejected. Needed for a live key, and for a test key on any site that is not localhost. Plain-http localhost is not admitted for live keys; use a test key locally. New fragment copy is not written from localhost |
| CSP | `connect-src` the API base; `img-src` and `media-src` the CDN origin; Spotify script and frame sources only if `mountAudio` is used |

`npx @sparkletree/cli doctor --url https://site/page --json` checks every row of this table and says what to fix. If the stream falls back: in log mode the response carries `x-st-auth: <reason>` (`missing_key`, `unsigned`, `bad_signature`, `org_mismatch`, `missing_origin`, `origin_not_allowed`, ...); in required mode it is a 401 with JSON `{ "error": "unauthorized", "reason": ..., "remedy": ... }` and `remedy` says what to fix.

No CSS ships. `.st-hero`, `.st-cta`, `.st-stream-text`, `.st-mark` are hooks for the site's own styles.

## Behaviour that matters when wiring

- A visitor always reads real copy. `fallback` is the floor; write it as the only version.
- Copy changes at most once per page view. A client-only mount holds the fallback invisible for up to 2.5 s (restarted once if the stream is alive, so up to 5 s) and types in whatever arrives first. Copy already on screen from server HTML is never typed over; the adapted version lands once, composed.
- `serverRendered` is for creative the platform rendered into the HTML, not for your own fallback. Leave it off; setting it on an ordinary fallback skips the hold and the fallback shows before the one change.
- Attach the `ref` from `useIsland` (the components do this for you). Impressions fire only once the element has been on screen; forget it and analytics read zero.
- Every adapted field is stamped `data-content-source`. A visible disclosure mark (`InlineMark`, "Adapted for you") is opt-in; `decideChrome` says when copy counts as adapted. Whether disclosure is a legal obligation (EU AI Act Article 50) is the integrator's call.

## Next.js App Router

Components are `"use client"` and still server-render, so the fallback is in the first paint. Put `SparkletreeProvider` in a client component, one per page view. The reservation is an `aria-hidden` span for up to the hold budget; strip `[aria-hidden="true"]` before asserting visible text in tests.

## Hooks for custom markup

`useIsland({ campaignId | surfaceId, island, fallback })` returns `{ state, ref }`. `state.fields.{greeting,headline,body,cta}` carry `{ text, source, mode, typing, settled }`; render each with `<StreamText field={...} as="h1" />` rather than `field.text`. `state.phase`: idle, holding, live, settled, failed. `state.degraded` means the server served a static winner on purpose; not an error.

`useFragments({ context, fields })` adapts copy you already have (a button label, a form heading) with your strings as the fallback and the schema; no dashboard object needed.

## Facts, custom slots and questions

- A price or another stated fact next to adapted copy: a field `{ kind: "fact", product: "<id or handle>", fact: "price", fallback: "249,00 kr" }` in `useFragments`, or `<Fact product="..." fact="price" fallback="..." />`. Facts are read from the workspace's records, never generated and never marked as adapted. Write the fallback as the formatted price will read. `fact: "availability"` needs `labels={{ in_stock: "In stock", out_of_stock: "Sold out" }}`.
- A campaign's custom slot: `{ kind: "slot", slot: "<name>", campaign: "<id>", fallback: "..." }`. It comes from the same variant the page's hero shows.
- A question box: `useAsk({ campaignId })` is headless and streams the answer; build the form in the site's own markup.
- For visiting agents: `<AgentSurface apiBase organizationId publishableKey campaignId />` from `@sparkletree/react/server` puts the stated facts in the page head as JSON-LD.

## Tests

`@sparkletree/core/testing` is a mock of the edge that needs no account: `mockFetch()` as the provider's `fetchImpl` in unit tests, `startMockEdge()` for browser tests, and `expectNoLayoutShift(page, action)` to prove adapted copy does not move the page. Failure names (`offline`, `slow`, `stall`, `error-mid-stream`, `http-500`, `quota`, `unauthorized`, `over-long`, `empty`) select what goes wrong. Write the degrade test first.

## Read results back

`npx @sparkletree/cli results <campaignId> --json`, or `getResults({ apiKey, campaignId })` from `@sparkletree/core/server` on a server, returns each variant's numbers, the leader, and which variant leads in which context (time of day, device and so on). It needs a CLI sign-in or a workspace API key and must never run in a browser. Use it before proposing copy changes.

## What the SDK sends

To the SparkleTree API only: time of day, weekday, timezone, language, coarse device type, referring origin (never the full URL), a per-tab random session id, impressions and clicks with variant and provenance. No geolocation, no fingerprinting, no third-party analytics. Disclosing this to visitors is the site owner's obligation.

## Verify

0. `npx @sparkletree/cli doctor --url https://site/page --json`: no `fail`.
1. Degrade: `npx @sparkletree/cli dev --failure offline` (or an unreachable `apiBase`), fallback visible, `phase: "failed"`, `rewrites: 0`, no `data-content-source="generated"`.
2. Happy path: real key, registered origin, the copy changes once, `data-content-source` present.
3. Analytics: `query_analytics` `action: snapshot` on the campaign shows impressions after a visit.
4. Site activity: the site's own actions (bookings, searches, taps on its own links) are not recorded by the components. Send them with `track` from `@sparkletree/core` as `references/site-activity.md` shows, and read them back with `query_analytics` `sections: ["siteActivity"]`.
