---
name: squid-design
description: SparkleTree custom Squid designs. Write a campaign's own HTML look for its Squid (layout, typography, motion, custom slots), preview it, publish it as a new variant, fill its slots, revert it, and record it as a short video with render_video mode squid. Use for design the ad, custom squid, make it look like our site, new layout, HTML ad, or a video of a design.
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

## 2. Write the draft

One complete HTML document (doctype to closing html tag), 512 KiB at most; CSS and JS inline or from https URLs. Do not copy the bridge script; call `sparkletree.ready()` once the first frame is drawn. The manifest:

```json
{
  "v": 1,
  "slots": [
    { "standard": "headline" },
    { "standard": "cta" },
    { "name": "offer_terms", "kind": "text", "label": "Offer terms", "maxLength": 120, "fallback": "While stocks last" }
  ],
  "capabilities": { "ask": true },
  "video": { "durationMs": 8000 }
}
```

Standard slots are greeting, headline, body and cta and are filled from the variant's copy. Custom slots have a `kind` of text, list, image or url; at most 24 slots. `video.durationMs` (3000 to 60000) sets the length of a recorded video. Designs show on every surface and aspect ratio, so lay out for both portrait and landscape.

`manage_campaigns` `action: create_component` with `campaignId`, `html`, `manifest` and a one-line `notes`. The member role can draft. The answer carries a `previewUrl` on the real host. Send it to the user and wait. Revise with another `create_component`; each call stores a new version.

## 3. Publish

On a clear yes, and with the admin role: `manage_campaigns` `action: publish_component` with `campaignId`, `componentId`, and optionally `copyFromVariantId` (whose copy the new variant starts from) and `variantName` (default "Design v{n}"). The response names the new variant and says whether the edge republished. A retry does not add a second variant.

If the user already approved the HTML, `create_component` with `publish: true` (plus `copyFromVariantId`, `variantName`) does both steps.

## 4. Fill custom slots

`manage_campaigns` `action: update_variant` with `contentStructure.squidSlots`: text and url as strings, list as an array of strings, image as `{url, alt}`. Sending `squidSlots` replaces the whole object, so send every slot, not only the changed one. The response lists `warnings` for values that do not fit the manifest. Read `query_campaigns` `action: variants` first.

## 5. Revert

`manage_campaigns` `action: revert_component` with `componentId` pauses the variants carrying the design (admin). The standard Squid variants keep running. Nothing is deleted; publishing again reactivates it.

## 6. Record it as a video

For a social clip of a variant that runs a published design: `render_video` `mode: squid` with `campaignId`, `variantId`, optional `formats` (9:16, 4:5, 1:1, 16:9; default 9:16 and 4:5) and `durationS` (3 to 60, default the manifest length). It spends workspace credits; 20 runs per workspace per day; confirm first. Poll `query_video` `action: progress` with the same `campaignId` and `variantId` every 15 to 30 seconds; each row in `squidExports[]` ends `ready` with `videoUrl` and `posterUrl`, or `failed` with an `error`. A 16:9 row may appear that you did not ask for; it is the share video.

## Errors

| Answer | Meaning |
|---|---|
| `not_configured` | Custom designs are switched off on this deployment. Not a bug; say it is not available yet |
| `forbidden`, read-only designs | The plan does not include publishing designs |
| `forbidden`, role | Draft needs member, publish and revert need admin |
| `precondition_failed` "not available" on `mode: squid` | Design video is switched off on this deployment |
| `precondition_failed` "publish a custom design" | The variant runs no published design; publish one first |
| `precondition_failed` in flight | A recording is already running; poll it |
| `squid_shape_not_v2` | The campaign uses the old Squid shape; the remedy says how to switch |
