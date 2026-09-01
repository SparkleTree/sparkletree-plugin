# Writing the brief

The brief is the only step where judgement matters more than tool knowledge. Generation turns intent into variants; a vague intent gives variants that differ only in adjectives.

## From goal to objective

| The user says | Objective | Metric to name |
|---|---|---|
| sell more, move stock, launch a product | increase_sales | conversions, revenue, add-to-cart |
| more visitors, foot traffic, sign-ups, downloads | drive_traffic | clicks, CTR (sessions), sessions |
| get known, new brand, new location | build_awareness | Reach, dwell, chip taps |
| an event, a date, a season | promote_event | bookings, RSVPs, QR scans |

## Constraints worth encoding

- Time: dayParts and daysOfWeek only when the offer is time-bound. A weekend brunch is; a year-round product is not.
- Location: city or near_store when the surface is physical or the offer is local.
- Audience: one behavioral segment beats three demographic ones.

## How variants should diverge

Pick angles, then let each variant own one:

- Price or value ("two for one until Sunday")
- Occasion ("the Friday after work")
- Feeling ("the quiet corner table")
- Proof ("rated 4.8 by 300 regulars")
- Urgency ("last 12 seats")

Ask the user for two or three angles, or propose them. State each variant as "angle: one line". The user approves the list, not the copy.

## Brand constraints

`query_brand` `action: get` returns voice (tone, personality, dos, donts) and messaging rules. Copy the relevant lines into `options.brandGuidelines`. If the workspace has no brand book yet, say so and offer `skills/brand-voice-sync` before generating; variants inherit brand colors at creation and keep them.

## Chips

Chips are shared across the campaign, up to six. Spend them on questions customers ask ("Do you deliver?", "Is there parking?"). Never on labels ("Learn more").

## The confirmation line

End the brief with the cost line and a question, for example:

"This runs one generation (credits from the workspace pool) and creates the campaign in review, unpublished. Go ahead?"
