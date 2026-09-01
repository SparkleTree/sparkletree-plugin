---
name: video-from-winner
description: SparkleTree campaign video. Render a short video or still from a winning campaign or a template with render_video, or commission a bespoke film with video_commission. Use for video, render, clip, film. Lists templates first (free), confirms the credit spend, starts the render, polls query_video progress and reports the download URL.
---

# Video from a winner

Two tools, two price classes. `render_video` renders a template on Remotion Lambda; a still or a draft is cheap, a final render costs credits. `video_commission` queues an agent-authored brand film with proofs and revision rounds; it is metered per workspace per day and is the expensive path. Default to `render_video`; offer a commission only when the user asks for a bespoke film.

## 1. Pick the source

- "From my best campaign": `query_analytics` `action: cvg_dashboard` for the window the user cares about; name the winning campaign and variant with the evidence (sessions, CTR (sessions)). Low sessions means say so.
- "From this campaign": `query_campaigns` `action: get`.
- Check for an existing render first: `query_video` `action: renders` with `campaignId`. A `status: ready` render with a `videoUrl` may already answer the request at no cost.

## 2. Free reads

`query_video` `action: templates` lists the templates. Pass `templateId` to expand one to its props schema, example props and example output. For a campaign render the template is `kinetic-promo`: headline, subheadline and body become beats, `cta.text` the CTA, brand colours the palette. All templates cap at 30 seconds.

## 3. Cheap iteration

Before any final render, show the user a still: `render_video` `mode: still` with `templateId`, `props`, optional `atSeconds`. Returns an image URL. For a template render, `quality: "draft"` is the next step up. Both spend from the credit pool; say so, but they are the cheap end.

## 4. Confirm, then render

State the mode, the campaign or template, the aspect, the quality and that it spends workspace credits. On yes:

- `render_video` `mode: campaign` with `campaignId`, optional `variantId` (one variant, otherwise all active variants up to the server cap), `aspect` (default 16:9), `quality` (draft or final). Returns one `campaignVideoRenderId` per variant.
- `render_video` `mode: video` with `templateId`, `props`, `quality`, optional `fileName`. Returns `renderId` and `bucketName`.

## 5. Poll and report

`query_video` `action: progress` with `campaignVideoRenderId`, or with `renderId` and `bucketName` for ad hoc renders. Progress is 0 to 1; done returns the download URL and size. Poll every 15 to 30 seconds; do not start a second render because the first is still running. Report the URL, duration, aspect and which variant it came from.

## Commissioning a film

Only on request. `video_commission` `action: create` with `briefMd` (goal, tone, what must appear, what must not), `aspects` (default 16:9), `targetDurationS` (up to 30), optional `soundtrackTrackRef`, `tier` (`marquee` fills a locked board scene, default; `atelier` writes free-form scene code from the brief). Confirm the metered spend first. Poll `query_video_commissions` `action: get` until `proof_ready`, show `proof.stills` and `proof.draftMp4`, then either `action: approve` (queues the final render, spends again, ends at `delivered` with `finalMp4`) or `action: revise` with notes (each round is metered; the response shows round and maxRounds). `action: cancel` stops a non-terminal commission. Soundtracks: only audio the user holds rights to.
