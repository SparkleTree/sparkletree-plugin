---
name: video
description: SparkleTree video. Render a short video or still from a campaign or a template with render_video, or check for an existing render first. Use for video, render, clip, reel, or a video of my best campaign. For a video of a custom Squid design, use squid-design.
---

# Video

`render_video` renders a template; a still or a draft is cheap, a final render is the expensive end; all count against a daily per-workspace limit. Ad hoc template renders are capped at 50 per workspace per day.

## 1. Pick the source

- "From my best campaign": `query_analytics` `action: cvg_dashboard` for the window the user cares about; name the winning campaign and variant with the evidence (sessions, CTR (sessions)). Low sessions means say so.
- "From this campaign": `query_campaigns` `action: get`.
- Check for an existing render first: `query_video` `action: renders` with `campaignId`. A `status: ready` render with a `videoUrl` may already answer the request at no cost.

## 2. Free reads

`query_video` `action: templates` lists the templates (logo-reveal, kinetic-promo, lightscribe). Pass `templateId` to expand one to its props schema, example props and example output. For a campaign render the template is `kinetic-promo`: headline, subheadline and body become beats, `cta.text` the CTA, brand colours the palette. All templates cap at 30 seconds.

## 3. Cheap iteration

Before any final render, show the user a still: `render_video` `mode: still` with `templateId`, `props`, optional `atSeconds`. Returns an image URL. For a template render, `quality: "draft"` is the next step up. Both count against the daily render limit; say so, but they are the cheap end.

## 4. Confirm, then render

State the mode, the campaign or template, the aspect, the quality and that it counts against the workspace's daily render limit. On yes:

- `render_video` `mode: campaign` with `campaignId`, optional `variantId` (one variant, otherwise up to four active variants), `aspect` (16:9 default, 9:16, 1:1), `quality` (draft or final). Returns one `campaignVideoRenderId` per variant.
- A variant that runs a custom Squid design is recorded with `mode: squid` instead; see `skills/squid-design` section 8.
- `render_video` `mode: video` with `templateId`, `props`, `quality`, optional `fileName`. Returns `renderId` and `bucketName`.

## 5. Poll and report

`query_video` `action: progress` with `campaignVideoRenderId`, or with `renderId` and `bucketName` for ad hoc renders. Progress is 0 to 1; done returns the download URL and size. Poll every 15 to 30 seconds; do not start a second render because the first is still running. Report the URL, duration, aspect and which variant it came from.
