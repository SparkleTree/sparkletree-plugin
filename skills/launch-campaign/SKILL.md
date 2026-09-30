---
name: launch-campaign
description: SparkleTree campaign launch from a product URL or a goal. Import or pick the product, write the brief, get approval, generate variants, poll, review, publish and deploy to a surface, then hand back the live link. Use when the user says launch, new campaign, get this live, campaign for, promote, brief or angle, or pastes a product URL with a marketing goal.
---

# Launch a campaign

Goal: a product URL or a plain-language goal becomes a live campaign with a URL the user can open. Read `skills/sparkletree` first if it is not already loaded; its rules (read before write, confirm before spend) apply throughout.

## 1. Product

- If the user gave a URL: `query_products` `action: list` with `search` first, since the product may exist. If not, confirm the credit spend, then `manage_products` `action: import_from_url` with `websiteUrl`. It reaches the open web and runs paid inference. Read the returned product back to the user (name, price, description, image). A `PRODUCT_EXISTS` answer means ask the user: use the match, or import again with `allowDuplicate: true`. Photos and other product work: `skills/products`.
- Otherwise `query_products` `action: list` and pick the product(s) the goal names. No product means no generation; ask the user which product or offer the import.

## 2. Brief

Write the brief before touching `generate_campaign`. Show it and wait for a yes. Use the `campaign_brief` server prompt when the host supports prompts; otherwise follow `references/brief.md`. The brief has exactly these parts:

1. Objective: one of increase_sales, drive_traffic, build_awareness, promote_event. Say which and why.
2. Outcome: one measurable sentence ("40 brunch bookings from the QR menu in September").
3. Audience and context: who, where, when. Only constraints that are true; leave the rest out.
4. Variants: how many and how they differ. Variants should diverge on angle (price, occasion, feeling, proof), not on wording of the same angle. Two to four is normal.
5. Brand constraints: pull tone and rules from `query_brand` `action: get`; note anything the user adds.
6. What it costs: one generation run from the workspace's credit pool, plus the product import if one happened.

## 3. Generate

On approval, `generate_campaign` `mode: start` with the intent shaped as in `skills/sparkletree/references/tools.md`. Pass `options.variantCount` and `options.brandGuidelines` from the brief. Then poll `query_campaigns` `action: generation_status` every 10 to 20 seconds until it completes or fails. Do not restart on "still running".

If generation fails, read the error remedy. `mode: regenerate` from the failing `fromStep` is the fix for a partial run; it costs credits again, so confirm.

## 4. Review

`query_campaigns` `action: variants` on the new campaign. Hand the variants to the `sparkletree:campaign-reviewer` agent when available, or run `skills/review-variants` yourself. Present the findings as a diff-style list. Apply approved edits with `manage_campaigns` `action: update_variant`. Saves republish automatically.

A generated campaign already carries its conversational playbook (the chat opening, product facts, FAQs and question chips the Squid answers with). A campaign made by hand with `manage_campaigns` `action: create` has none; publishing adds one automatically, and `manage_campaigns` `action: generate_playbook` with the `campaignId` writes or rewrites it on demand after product or variant edits. It runs paid inference; confirm first.

## 5. Publish and deploy

Ask which surface. `query_surfaces` `operation: list_surfaces` (and `list_zones`) to find it by name. Then, after one combined confirmation naming the campaign, the surface and the visibility:

1. `manage_campaigns` `action: publish` with `visibility: "public"` if the page should be reachable at its URL.
2. `manage_campaigns` `action: deploy` with `surfaceId` or `zoneId` (exactly one).
3. If the campaign is still in review, `manage_campaigns` `action: update` with `status: "active"`. If the answer carries `approval: {status: "required"}`, the workspace wants a second approver: tell the user who must approve, and stop.

If the user has no surface yet, the brand page already carries every published campaign; publishing alone is enough for a first launch. Offer `skills/surfaces-and-embed` for the website, screen and QR routes.

## 6. Hand back

Return: campaign name and id, variant count, the surface, and the live URL. The campaign page lives on the brand host (`https://<workspace-slug>.sparkletree.io/...` or the custom domain); `query_campaigns` `action: get` returns the page URL once published. Verify it by fetching the URL with `Accept: text/markdown` if a fetch tool is available.

## Stop conditions

Stop and ask instead of guessing when: no product resolves; the objective is ambiguous between two of the four; the workspace returns `precondition_failed` for quota or credits (read `details.code`); the user has not approved the brief.
