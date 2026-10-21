# Site activity: record what visitors do

The SparkleTree dashboard has a **Site activity** panel (Dashboard > Analytics) for what people do on the workspace's own sites: a custom brand page, a site built with the SDK, and pages with an embedded campaign. Each event kind is one row with its count, sessions and site, and each detail the site sent can be broken down value by value (which search terms, which buttons). A site gets there only if it sends the events, so wire them while you build the page, not later.

## What is recorded without any code

- Brand page views, per page path, with the visit's source, device and country (Site activity > Views by page, and Sessions). Never add a page view of your own.
- Impressions and clicks on campaign creative: the edge script tag, the brand page embed and the SDK components (`Hero`, `Cta`, `useIsland` with its `ref` attached) record them.

## What the site has to send

Everything else: taps on the site's own links and buttons, searches, filters, steps in a flow. Ask the user which actions they want to see, then send each with the SDK's `track`.

```ts
track(context: { apiBase: string; organizationId: string; campaignId: string }, eventType: "click" | "custom", eventData: { context: Record<string, unknown> })
```

- On a custom brand page: load `/api/embed/v1/sdk/core.js` (once, without `async` or `defer`) and call `SparkleTree.track`, with `apiBase: location.origin`. No publishable key is needed there. The page's agent guide (`query_brand` `action: get_page`, section "Measure what visitors do") has the exact snippet with the organization id filled in.
- On the user's own site: `import { track, decodePublishableKey } from "@sparkletree/core"`. `decodePublishableKey(publishableKey)` gives `apiBase` and `organizationId`.

```ts
import { decodePublishableKey, track } from "@sparkletree/core";

const { apiBase, organizationId } = decodePublishableKey("st_pk_live_..."); // the publishable key from the dashboard
const st = { apiBase, organizationId, campaignId: "<a campaign id of this workspace>" };

export function record(type: "click" | "custom", context: Record<string, unknown>) {
  void track(st, type, { context: { path: location.pathname, ...context } });
}

// A tap on the site's own button:
record("click", { kind: "book_table", restaurant: "east-side" });
// A search, once the visitor has stopped typing (never per keystroke):
record("custom", { kind: "search", q: query, results: matches.length });
```

## The rules the panel depends on

- `campaignId` is required by the server. Any campaign of the workspace is accepted; use the campaign the site promotes, or one the user names. With no campaign yet, leave tracking out and say so.
- `"click"` for taps on links and buttons. These count as site clicks, separate from campaign clicks, so they never change a campaign's click-through rate. `"custom"` for everything else.
- Every detail goes inside `eventData.context`. Other keys are dropped by the server.
- `context.kind` is the event's name in Site activity (`book_table` shows as "Book table"). Without it the row is just "Click" or "Custom", so always set it.
- Every other `context` key is offered as a breakdown. Names start with a letter, then letters, digits or `_`, at most 41 characters. Values are strings, numbers, booleans or lists of those; a nested object has no value to count. A string longer than 2048 characters is dropped.
- A number named `results` also shows how many searches found nothing. Use that name for result counts.
- Send `path: location.pathname` (no query string) so events can be broken down by page.
- The server adds the session, device, country and the site (from the page's own address). Do not send `device` or `pageHost`. Never send a `v3` key: it is reserved for Squid design events.
- Never personal data: no names, emails, phone numbers, account ids or exact locations. A search term is fine.
- Never record impressions or clicks on campaign creative yourself; they are already counted.
- `track` never throws and uses `keepalive`, so a tap on a link that leaves the page is still recorded. Do not wait for it.
- Events sent while developing, from localhost or a preview, land in the same analytics. Keep test traffic small, or wire tracking last.

## Checking it

In the browser, each event is one `POST /api/embed/v1/track` that answers 202. After a test visit, read the events back (they appear within a few minutes):

- `query_analytics` `action: snapshot` with `startDate`, `endDate` and `sections: ["siteActivity"]`. `siteActivity.kinds` lists each kind with its `key` (`source:eventType:name`, for example `sdk:custom:search`), `label`, `source` (`sdk`, `brand_page` or `embed`), `site`, `count`, `sessions`, `properties` and `zeroResultCount` (searches that found nothing). `siteActivity.pages` lists brand page views by path.
- `siteActivityBreakdown: {kind, property, limit?}` lists one property of one kind value by value, for example `{kind: "sdk:custom:search", property: "q"}` for the search terms.
- The section covers whole UTC days and the whole workspace. With `campaignIds`, `productIds`, `storeIds` or `eventTypes` it answers `available: false`, so ask for it without those filters.

The user sees the same figures in Dashboard > Analytics > Site activity.
