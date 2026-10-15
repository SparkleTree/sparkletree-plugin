---
name: squid-design
description: SparkleTree custom Squid designs and templates. Find a ready-made template that suits the business or write a campaign's own HTML look (layout, typography, motion, custom slots), check it, preview it, publish it as a new variant, fill its slots, revert it, and record it as a short video with render_video mode squid. Use for design the ad, template, custom squid, make it look like our site, new layout, HTML ad, or a video of a design.
---

# Custom Squid designs

A design is one HTML document plus a manifest of slots. Publishing a design does not overwrite anything: it adds a new variant carrying the design, so Adaptive CVG tests it against the existing variants. Read `skills/sparkletree` first if it is not loaded.

## 1. Read

1. `query_campaigns` `action: get_component` with `campaignId`. It returns:
   - `liveByVariant`: which design each variant runs (none means the standard Squid).
   - `components[]`: every stored design with `previewUrl` and the `variantIds` that carry it.
   - `permissions`: `canDraft`, `canPublish`, and `publishBlockedReason` (role, shape, plan or disabled).
   - `delivery`: whether the page is published and whether it needs a republish.
   - `agentGuide`: the authoring rules. The same text is the resource `mosaic://campaigns/{campaignId}/squid-component-guide`.
2. Read the guide before writing anything. It carries the brand palette and fonts, the current copy of every variant, the size limits, and the `window.sparkletree` bridge the platform injects (slot values, the surface size, `ready()`). If the guide says the campaign is not on the V2 shape with the copy card yet, drafts still work but publishing is refused: tell the user to switch the shape in the dashboard first.
3. `query_brand` `action: get` for colours, fonts and voice, and `query_campaigns` `action: variants` for the copy the design will carry.

If `publishBlockedReason` is `plan` or `disabled`, say so before writing anything: the workspace can look but cannot publish designs.

## 2. A ready-made template first, when it fits

The Squid template library holds finished designs. When the user wants a new look but has no design of their own, offer templates before writing one from scratch.

1. `query_campaigns` `action: match_templates` with `campaignId` (member role): the templates that suit the campaign's business, best first, each with reasons and a `previewUrl`. `mode: "cast"` spreads the picks from calm to spectacular and serious to playful. It may make a model call (30 uncached matches per workspace per day; a match is kept for 7 days), so ask first. `action: list_templates` with an optional `query` browses the whole library without a model call.
2. Show the user two or three matches with their preview links and reasons, and let them pick.
3. `manage_campaigns` `action: apply_template` with `campaignId` and `templateId`. Without `publish` it stores a draft design baked with the brand book and returns its `previewUrl` (member). With `publish: true` (admin, on a clear yes) it adds the design as a new variant at once; `slotValues` fills its custom slots and wins over the product and the source variant.
4. Read `emptyClaimSlots` in the answer: price, offer, dates and other claims the template could not fill. They show empty until you set them with `update_variant` `contentStructure.squidSlots` (section 6), using the customer's real facts only. Read the `summary` back to the user.

To start your own design from a template instead, `query_campaigns` `action: get_template` with `templateId` and `campaignId` returns `starter` (the template's HTML and manifest baked with the brand); change it and save it with `create_component`.

The library is off on some deployments: then every template action answers `not_configured` ("the squid template library is not enabled for this server"). Say that templates are not available yet and continue with a custom design; do not retry.

## 3. Write the draft

One complete HTML document (doctype to closing html tag), 512 KiB at most; CSS and JS inline or from https URLs. Do not copy the bridge script; call `sparkletree.ready()` once the first frame is drawn. The manifest:

```json
{
  "v": 1,
  "slots": [
    { "source": "standard", "name": "headline" },
    { "source": "standard", "name": "cta" },
    { "source": "custom", "name": "offer_terms", "kind": "text", "label": "Offer terms", "maxLength": 120, "fallback": "While stocks last" }
  ],
  "capabilities": { "ask": true },
  "video": { "durationMs": 8000 }
}
```

Standard slots (`source: "standard"`) are greeting, headline, body and cta and are filled from the variant's copy. Custom slots (`source: "custom"`, a lowercase `name` of up to 32 characters) have a `kind` of text, list, image or url; at most 24 slots. `video.durationMs` (3000 to 60000) sets the length of a recorded video, and `video.viewport` (`"output"` or `{width, height}` in CSS px, 320 to 1920) the size the design is laid out at when it is recorded. Designs show on every surface and aspect ratio, so lay out for both portrait and landscape.

`manage_campaigns` `action: create_component` with `campaignId`, `html`, `manifest` and a one-line `notes`. The member role can draft. The answer carries a `previewUrl` on the real host. Send the `previewUrl` to the user, not the `documentUrl` (a browser tab opened on the document shows nothing). Revise with another `create_component`; each call stores a new version.

## 4. Check the draft

`query_campaigns` `action: check_component` with the `componentId` (member role). The static checks of the HTML and manifest come back at once and cost nothing. Where browser checks are switched on, the call also starts a browser check at five sizes (360x800, 600x600, 1280x720, 1200x300 and 540x960) in a sandbox, 20 per workspace per day, which takes a minute or two: ask first, then call again until `browserCheck.status` is `done`. Open every `screenshotUrl` and look at it; a design can pass every check and still look wrong. Fix what the findings name with a new `create_component` and check the new version. When browser checks are off, `browserCheck.status` is `not_run` with the reason; open the preview at a phone and a wide size yourself. Every finding is a warning; nothing blocks publishing. Follow `next` in the answer.

## 5. Publish

On a clear yes, and with the admin role: `manage_campaigns` `action: publish_component` with `campaignId`, `componentId`, and optionally `copyFromVariantId` (whose copy the new variant starts from) and `variantName` (default "Design v{n}"). The response names the new variant and says whether the edge republished. A retry does not add a second variant.

If the user already approved the HTML, `create_component` with `publish: true` (plus `copyFromVariantId`, `variantName`) does both steps.

## 6. Fill custom slots

`manage_campaigns` `action: update_variant` with `contentStructure.squidSlots`: text and url as strings, list as an array of strings, image as `{url, alt}`. Sending `squidSlots` replaces the whole object, so send every slot, not only the changed one. The response lists `warnings` for values that do not fit the manifest. Read `query_campaigns` `action: variants` first.

## 7. Revert

`manage_campaigns` `action: revert_component` with `componentId` pauses the variants carrying the design (admin). The standard Squid variants keep running. Nothing is deleted; publishing again reactivates it.

## 8. Record it as a video

For a social clip of a variant that runs a published design: `render_video` `mode: squid` with `campaignId`, `variantId`, optional `formats` (9:16, 4:5, 1:1, 16:9; default 9:16 and 4:5) and `durationS` (3 to 60, default the manifest length). It is recorded in a sandbox, not with render credits, and counts against 20 recordings per workspace per day; confirm first. A Starter workspace or one without an active plan cannot record (`forbidden`). Poll `query_video` `action: progress` with the same `campaignId` and `variantId` every 15 to 30 seconds; each row in `squidExports[]` ends `ready` with `videoUrl` and `posterUrl`, or `failed` with an `error`. A 16:9 row may appear that you did not ask for; it is the share video.

## Errors

| Answer | Meaning |
|---|---|
| `not_configured` | Custom designs, or the template library, are switched off on this deployment. Not a bug; say it is not available yet |
| `forbidden`, read-only designs | The plan does not include custom designs (Starter or no active plan). Applies to drafts, templates, checks and design video too |
| `forbidden`, role | Draft, apply as draft, check, match and get a template need member; publish, apply with `publish: true` and revert need admin |
| `upstream_error` on `mode: squid` | The plan lookup failed; nothing was queued. Retry once later |
| `precondition_failed` on `apply_template` | The campaign is on the old Squid shape, the template is excluded, or a write raced; the remedy says which |
| `precondition_failed` "not available" on `mode: squid` | Design video is switched off on this deployment |
| `precondition_failed` "publish a custom design" | The variant runs no published design; publish one first |
| `precondition_failed` in flight | A recording is already running; poll it |
| `squid_shape_not_v2` | The campaign uses the old Squid shape; the remedy says how to switch |
| Daily limit on `check_component` | The browser check did not run (`not_run` with the reason); the static findings still came back. Try tomorrow (UTC) |
