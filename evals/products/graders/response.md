---
type: regex
target: last_message
pattern: 'upload_asset|imageAssetId|already (exists|have)|allowDuplicate'
flags: 'i'
match: contains
---
The plan uploads the local photo with upload_asset (or explains the public-link route), attaches it with imageAssetId, and says what happens if the product already exists.
