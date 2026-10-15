---
type: regex
target: last_message
pattern: 'edit_page|create_version|put_files|check_page'
flags: 'i'
match: contains
---
The plan reads the page version first, makes a small exact-text edit as a draft, adds the events page to a draft version, checks it, and publishes only on approval.
