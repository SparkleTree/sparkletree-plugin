---
type: regex
target: last_message
pattern: 'brief.*(approv|confirm|yes)|(approv|confirm).*brief'
flags: 'i'
match: contains
---
The plan shows a brief and stops for approval before generation and before publish or deploy.
