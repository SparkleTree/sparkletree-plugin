---
name: digest
description: SparkleTree campaign analytics digest command, /sparkletree:digest [days]. Delegates to the analytics-digest agent for the last 7 days by default, reports Impressions and Reach separately, names winners and stalls per campaign, and proposes variant edits as a list that waits for approval before anything is written.
disable-model-invocation: true
argument-hint: "[days]"
---

Produce the analytics digest for the last $ARGUMENTS days (default 7) using the `sparkletree:analytics-digest` agent. If the agent is not available, follow its procedure yourself: `query_analytics` `action: snapshot` with `sections: ["summary"]` for the window, then `action: cvg_dashboard`, then one insight per campaign at most.

Output: workspace name; the window; top line (Impressions, Reach, clicks, conversions, with Impressions and Reach never merged); per campaign one line with the winning variant and its evidence or "keep collecting"; a list of proposed edits (`manage_campaigns` `update_variant` or `isActive: false`) that is not applied until the user says yes.
