---
name: review-variants
description: SparkleTree variant review. Critique a campaign's variants against a fixed checklist (claim accuracy, voice, headline, CTA, chips, legal flags, copy accessibility, divergence) and turn each finding into an update_variant edit that waits for approval. Use after a generation completes, or for which variant is better, is this on brand, critique the copy, or review this Squid.
---

# Review variants

Read first: `query_campaigns` `action: get` with `include: ["variants", "products"]`, and `query_brand` `action: get` for voice and rules. If the campaign has traffic, `query_analytics` `action: cvg_dashboard` with the `campaignId` tells you what is winning; a variant with under a few hundred sessions is not yet evidence either way.

Then run the checklist in `references/checklist.md` on every active variant. Report per variant, in this order: verdict (keep, edit, retire), findings with the exact text quoted, proposed replacement text.

## Rules

- Quote the field you are judging (kicker, headline, body, CTA, chip). Do not paraphrase what you criticise.
- One finding, one fix. A proposed edit is the full new value of one field.
- Claim accuracy is checked against the product record and the brand facts, never against general knowledge. A claim you cannot verify is flagged, not fixed.
- Do not retire a variant on early numbers. Say "keep collecting" when sessions are low.
- Nothing is written without the user's yes. Present the edits as a list; on approval, apply each with `manage_campaigns` `action: update_variant` (`campaignId`, `variantId`, `contentStructure` with the changed fields). To retire, `update_variant` with `isActive: false` rather than `delete_variant`, unless the user asks to delete.

## Output shape

```
Variant "Friday after work" (id …): edit
- Headline claims "Stockholm's best" with no source. Replace with "Rated 4.8 by 300 regulars" (from brand facts).
- CTA "Learn more" is a label. Replace with "Book a table".
Variant "Quiet corner" (id …): keep
Chips: 4 of 6 used; suggest adding "Do you take walk-ins?"
Apply the two edits? Saves republish the live surfaces immediately.
```
