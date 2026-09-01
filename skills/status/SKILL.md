---
name: status
description: SparkleTree campaign workspace status command, /sparkletree:status. Free reads only. Confirms which workspace the session is bound to, checks server health, lists live and in-review campaigns, running generations and renders, and the products and surfaces count, in under ten lines.
disable-model-invocation: true
---

Report the state of the connected SparkleTree workspace using reads only. No writes, no credit spend.

1. `get_platform_info` `topic: "health"`.
2. `get_platform_info` `topic: "organization"`: name, plan, counts.
3. `query_campaigns` `action: list` with `status: "active"`, then `status: "review"`, then `status: "generating"` (limit 10 each). For any generating campaign, `action: generation_status`.
4. `query_video` `action: renders` (newest first, limit 5) for renders in progress.
5. `query_surfaces` `operation: list_surfaces` (limit 5) for the count.

Print at most ten lines: workspace, health, live campaigns by name, campaigns in review, running jobs, products and surfaces counts, and one suggested next step. If any call returns 401 or the tools are missing, run `skills/troubleshoot-connection` instead of guessing.
