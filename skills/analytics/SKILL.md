---
name: analytics
description: SparkleTree campaign analytics and reports. Answer how campaigns did, which variant is winning, what stalled, or write a weekly digest for a window (default 7 days), with Impressions and Reach kept separate. Reads only; proposed variant edits wait for approval. Use for how did my campaigns do, results, performance, weekly report, digest, CTR, which ad wins.
argument-hint: "[days or question]"
---

Answer the analytics question, or write the digest for the last $ARGUMENTS days (default 7). Reads only.

Where subagents exist, hand the digest to the `sparkletree:analytics-digest` agent and relay its result. Otherwise:

1. `get_platform_info` `topic: "organization"`; name the workspace.
2. `query_analytics` `action: snapshot` with `startDate`, `endDate` (inclusive), `granularity: "day"`, `sections: ["summary"]`. Widen `sections` only when the question needs it (`breakdowns` for per-campaign columns, `funnel` for drop-off, `timeseries` for a trend). `spend` is plan gated and fails the whole call without the plan; ask for it alone.
3. `query_analytics` `action: cvg_dashboard` for variant performance and winners; `action: ab_test` with `campaignId` where a test runs.
4. `query_campaigns` `action: list` with `status: "active"` to name campaigns and catch live ones with no traffic.

Rules for the numbers: Impressions are raw deliveries, Reach is distinct sessions; report both and never merge them. Compare creatives on CTR (sessions), not raw CTR. Screens reload, so a high Impressions to Reach ratio is normal there. A variant under a few hundred sessions is "keep collecting", not a loser. A low conversion rate with a healthy CTR points after the click. Window limits: hourly up to 14 days, daily up to 366; on `analytics_window_too_large`, coarsen the granularity.

Digest shape: workspace and window; top line (Impressions, Reach, clicks, conversions, revenue if present); per active campaign one line with the winning variant and its evidence, a stall and its likely reason, or "keep collecting"; proposed edits as a list of `manage_campaigns` `update_variant` calls (copy tightening, `isActive: false` for a clear loser) that are not applied until the user says yes. For a single question, answer it in two to five lines with the numbers behind it.
