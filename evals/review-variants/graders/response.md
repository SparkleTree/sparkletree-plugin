---
type: regex
target: last_message
pattern: 'claim|voice|CTA|legal|access'
flags: 'i'
match: contains
---
The answer applies the fixed checklist (claim accuracy, voice, CTA, legal flags, accessibility) and proposes edits as update_variant that wait for approval.
