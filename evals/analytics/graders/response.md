---
type: regex
target: last_message
pattern: 'impressions|reach|cvg_dashboard|sessions'
flags: 'i'
match: contains
---
The plan reads snapshot and cvg_dashboard, keeps Impressions and Reach separate, and treats low sessions as keep collecting.
