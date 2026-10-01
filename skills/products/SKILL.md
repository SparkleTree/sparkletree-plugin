---
name: products
description: SparkleTree products and product images. Add, import, edit or delete products; upload a photo or video file into the workspace with upload_asset, or find one already stored with query_assets; manage a product's image gallery; import a CSV catalogue; handle the "product already exists" answer. Use for add a product, import from my shop, upload this image, product photos, change a price, or when a campaign needs a product that does not exist yet.
---

# Products and images

Campaigns are generated from products, so a product with a real name, price and image is the input every later step depends on. Read `skills/sparkletree` first if it is not loaded.

Read first: `query_products` `action: list` with `search` to see what exists, and `action: get` for one product (it returns the gallery as `images[]` with ids).

## Add a product

| The user has | Call | Cost |
|---|---|---|
| A product page URL | `manage_products` `action: import_from_url` with `websiteUrl` | Paid inference and the open web; confirm first. Read the result back (name, price, description, image) |
| The details in chat | `manage_products` `action: create` with `name` and what they gave you (`description`, `price`, `currency`, `sku`, `websiteUrl`, `category`, `tags`) | Product quota |
| A spreadsheet or feed | `manage_products` `action: import_csv` with `csvContent` (2 MB max) or `csvUrl`; poll `query_products` `action: import_status` with the `jobId` | Product quota per new row |

Never invent a price. If the page shows none, leave it empty; `update` with `price: null` clears a wrong one.

### "You already have this product"

`create` and `import_from_url` check for an existing product first and answer `precondition_failed` with `details.code: "PRODUCT_EXISTS"` and `details.matches` (id, name, image, `strength: exact or possible`). Do not retry on your own. Show the matches and ask: use the existing one (continue with its id), or add a new one (repeat the call with `allowDuplicate: true`).

If a site refuses the import (`upstream_error`, `details.reason`: blocked, rate-limited, not-found, unreachable, unreadable), say which, and offer `create` with the details the user can paste.

## Images

A product holds up to five images; the first is the primary image that campaigns use.

1. Get the file into the workspace:
   - A public link to the image itself: pass it as `imageUrl`. The server downloads and stores a copy; if it cannot, the call fails rather than saving a link that may break later.
   - A small local file or a screenshot (1 MB at most): `upload_asset` `action: from_data` with the file as base64 or a data URI and a `filename`.
   - A larger local file: `upload_asset` `action: create_upload` with `filename` and `bytes` (the exact size). Run the returned curl line (it PUTs the file to `uploadUrl` as form field `file`) if you have a shell; otherwise give the user the line. Then `upload_asset` `action: complete_upload` with the `uploadId`.
   - A file that may already be in the workspace: `query_assets` `action: list` (newest first, `kind: image`) and use its `assetId`. Sending the same file again also returns the stored one (`reused: true`).
   - `upload_asset` answers with `asset.assetId`; pass it as `imageAssetId`.
2. Attach it:
   - New product: `create` with `imageUrl` or `imageAssetId`.
   - Replace the primary image: `update` with `imageUrl` or `imageAssetId` (the rest of the gallery stays).
   - Add to the gallery: `add_image` with one of the two, optional `makePrimary: true`.
3. Arrange: `query_products` `action: get` for the image ids, then `set_primary_image` or `remove_image` with `imageId`, or `reorder_images` with every id exactly once.

Accepted: JPEG, PNG, WebP, GIF, AVIF (16 MB); MP4, MOV, WebM for video (64 MB by link, 128 MB through `create_upload`), but a product image must be an image. `import_from_url` copies the page's image into the workspace itself. HEIC, SVG, PDF and web pages are refused; the error says how to convert. An older product that only has an image link shows an empty gallery; `add_image` starts the gallery from that link first.

A sixth image returns `precondition_failed` with `PRODUCT_IMAGE_LIMIT`: ask which image to remove.

## Edit and delete

`update` with `productId` and only the fields that change. `delete` is permanent and campaigns that use the product lose it; confirm by name first.

## Hand back

Name, id, price, primary image URL and how many gallery images, or the exact error and remedy. Offer `skills/launch-campaign` when the user wants to market the product next.
