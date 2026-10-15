---
type: regex
target: last_message
pattern: 'match_templates|list_templates|apply_template'
flags: 'i'
match: contains
---
The plan ranks or lists templates, shows previews, applies the chosen one as a draft or publishes it only on approval, fills the empty claim slots with real facts, and treats not_configured as "not available yet" rather than an error to retry.
