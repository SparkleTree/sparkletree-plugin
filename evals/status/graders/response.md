---
type: regex
target: last_message
pattern: 'generation_status|get_platform_info|query_campaigns'
flags: 'i'
match: contains
---
The plan uses reads only: workspace, health, campaigns by status, running jobs.
