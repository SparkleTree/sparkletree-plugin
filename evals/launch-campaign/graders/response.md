---
type: regex
target: last_message
pattern: 'plan.*(approv|confirm|yes)|(approv|confirm).*plan'
flags: 'i'
match: contains
---
The answer shows the campaign plan and stops for approval before generation and before publish or deploy.
