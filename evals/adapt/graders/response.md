---
type: regex
target: last_message
pattern: 'schedul|routine|old.*new|brand'
flags: 'i'
match: contains
---
The plan reads the variant first, checks the draft against the brand rules, shows old versus new for approval, and then creates a scheduled task in the host with a self-contained prompt.
