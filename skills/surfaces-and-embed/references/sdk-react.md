# React SDK reference

Packages: `@sparkletree/core` (framework-agnostic wire and copy choreography), `@sparkletree/react` (provider, hooks, components), `@sparkletree/cli` (`npx @sparkletree/cli add hero cta` copies component source into the repo in the shadcn style; `sparkletree upgrade` ports older copies). Repo: https://gitlab.com/sparkletree/sparkletree-sdk.

## Minimum integration

```tsx
import { SparkletreeProvider, Hero, Cta } from "@sparkletree/react";

<SparkletreeProvider publishableKey={process.env.NEXT_PUBLIC_SPARKLETREE_KEY}>
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
| `publishableKey` | Dashboard. A signed credential, required on every request. `st_pk_test_...` works on its own for local development; `st_pk_live_...` only works from a registered origin. Visible in page source, so protection is the origin registry plus rate limits; rotate from the dashboard if it leaks |
| `campaignId` | Dashboard, or `query_campaigns` `action: list`. `surfaceId` may be used instead when a surface decides what plays |
| Allowed origin (live keys) | Register the site origin per workspace; wildcards rejected. Plain-http localhost is not admitted for live keys; use a test key locally |
| CSP | `connect-src` the API base; `img-src` and `media-src` the CDN origin; Spotify script and frame sources only if `mountAudio` is used |

If the stream falls back: in log mode the response carries `x-st-auth: <reason>` (`missing_key`, `unsigned`, `bad_signature`, `org_mismatch`, `missing_origin`, `origin_not_allowed`, ...); in required mode it is a 401 with JSON `{ "error": "unauthorized", "reason": ..., "remedy": ... }` and `remedy` says what to fix.

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

## What the SDK sends

To the SparkleTree API only: time of day, weekday, timezone, language, coarse device type, referring origin (never the full URL), a per-tab random session id, impressions and clicks with variant and provenance. No geolocation, no fingerprinting, no third-party analytics. Disclosing this to visitors is the site owner's obligation.

## Verify

1. Degrade: unreachable `apiBase`, fallback visible, `phase: "failed"`, `rewrites: 0`, no `data-content-source="generated"`.
2. Happy path: real key, registered origin, the copy changes once, `data-content-source` present.
3. Analytics: `query_analytics` `action: snapshot` on the campaign shows impressions after a visit.
