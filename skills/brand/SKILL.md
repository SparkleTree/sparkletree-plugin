---
name: brand
description: SparkleTree brand book, voice and brand page. Set up or refresh logo, colours, fonts, tone, dos and donts, messaging and the concierge answers from a website or documents, and author, edit, check, publish or revert the brand home page or a multi-page brand site. Use for import our brand, tone of voice, brand colours, brand guidelines, concierge, brand page, brand site, or onboarding a new SparkleTree workspace.
---

# Brand book, voice and brand page

The brand book is what every generated variant, Squid and page inherits. Get it right once and generation stays on voice; leave it empty and every campaign starts from nothing.

Brand data writes (brand book, profile, voice, concierge, logo) need the admin role (a workspace API key counts as a member and cannot make them). Brand page drafts are the exception: a member can create, edit and check a draft and add files to it; publishing, reverting and deleting need an admin. The plan matters too: a workspace without an active plan cannot change brand data, a Starter workspace that holds a verified address cannot either, and every brand page action needs a plan that includes publishing a brand page. The `forbidden` answer says which. Check with `get_platform_info` `topic: "organization"`; if the user is not an admin, prepare the content and hand it over instead of calling `manage_brand`.

## 1. Read what exists

`query_brand` `action: get`. Note which subtrees are filled: brandbook (logo, colors, fonts, imagery), guidelines (voice, messaging, contentRules), profile (website, socials, location), voice (eyebrow, tagline, fonts), concierge (chips, facts, FAQ, policies, catalog mode).

## 2. Gather the source

- A website: fetch the homepage and one or two product or about pages as markdown if a fetch tool exists. Pull the tagline, recurring phrases, how they address the reader (you, we, formal, casual), what they never say, and the five colours if the CSS is reachable. The dashboard also has "Start from your website" under Brand, which drafts the same fields; mention it if the user prefers a visual review.
- Documents the user pastes: brand guidelines, tone-of-voice decks, past campaigns.
- The user's own words: ask at most three questions (how should the brand sound in one sentence; three words it is; three words it is not).

## 3. Draft

Produce, and show, before writing:

- voice: tone (one sentence), personality (one sentence), dos (up to 8), donts (up to 8)
- messaging: tagline, key messages, proof points that are actually true
- contentRules: anything legal or regulatory (alcohol, health, finance, children)
- profile: website, socials, location
- concierge: six chips that are real customer questions, the facts the `/ask` assistant may state (hours, address, delivery, returns), policies, FAQ
- colors: primary, secondary, accent, background, text as CSS values. Renderers read these five slots.
- fonts: heading and body font families, if the site shows them. The website import does not bring fonts over this connection; set them in `brandAssets.fonts` or `voice.headingFont` and `voice.bodyFont`.

Logo: use `manage_brand` `action: set_logo` (step 4), not a link inside `brandAssets`. Imagery is stored as links; use a link the brand controls, or put the file in the workspace first with `upload_asset` and use the returned `asset.url`.

Keep everything factual. The concierge answers visitors on the public brand page; anything written here is said to customers.

## 4. Write, subtree by subtree

After the user approves, write only the subtrees you changed. Writes merge per subtree: what you send replaces that subtree, what you omit is preserved.

- `manage_brand` `action: update_brandbook` with `brandAssets` (logo, colors, fonts, imagery) and `brandGuidelines` (voice, messaging, contentRules)
- `manage_brand` `action: update_profile` with `profile`
- `manage_brand` `action: update_voice` with `voice` (eyebrow, tagline, headingFont, bodyFont, tone)
- `manage_brand` `action: update_concierge` with `concierge` (chips, inputHint, language, assistant, hideCampaigns)
- `manage_brand` `action: set_logo` with `logoSlot` (primary by default; light, dark or icon) and exactly one of `logoAssetId` (from `upload_asset` or `query_assets`) or `logoUrl`. A link is downloaded and stored in the workspace. PNG, JPEG, WebP, GIF or AVIF; SVG is refused, so export it as PNG first. Other slots are kept.

Edge caches invalidate in the same call. Published campaign pages bake visuals at publish time; if colours or the logo changed, republish the affected campaigns with `manage_campaigns` `action: publish` (confirm first). Existing variants keep the colour scheme they inherited.

## 5. Verify

`query_brand` `action: get` again and read the result back in two lines. If the brand page is published, its `/llms.txt` and `/ask` now answer with the new facts; suggest one test question.

## 6. The brand home page, if the user wants it authored

The brand host (`<slug>.sparkletree.io` or the custom domain) renders a default home page from the brand book. An agent can replace it with a hand-authored page, or a small site of several pages with its own CSS, scripts and images. Only do this when the user asks for it; the default render is fine for most workspaces.

`manage_brand` is marked destructive, so some hosts ask before every call, drafts included. Say so once if the user wonders why.

1. `query_brand` `action: get_page`: the live state, the newest 20 stored versions with their preview URLs, and the agent guide. The same guide is the resource `mosaic://brand-page-guide`. Read it before writing: it carries the palette, the live campaign ids, the relative embed and link paths the edge serves, and the rules.
2. Write one complete, self-contained HTML document (doctype to closing html tag, 1 MiB at most). Use only the paths the guide names for campaign embeds and links; nothing external that the page cannot live without.
   Measurement: page views per page path are recorded by the edge, so add no analytics tag or page view of your own. Ask the user which visitor actions they want to see in Dashboard > Analytics > Site activity (taps on directions or booking links, searches, filters) and record each one as the guide's "Measure what visitors do" section shows: `SparkleTree.track` from `/api/embed/v1/sdk/core.js`, a campaign id of the workspace, `"click"` for taps and `"custom"` for the rest, every detail inside `context`, `context.kind` as the event's name, no personal data. Name the recorded actions when you show the preview; after the first visits to the live page, `query_analytics` `sections: ["siteActivity"]` shows them.
3. `manage_brand` `action: create_page` with `html` and a short `notes` line. Without `publish` it stores a draft and returns a signed preview URL on the real host, the check result and the `sha256`; the member role is enough for a draft. Show the user the preview URL and wait.
4. Small fixes: do not resend the whole page. `query_brand` `action: get_page` with `pageId` returns the version's HTML and `sha256` (`lines: {from, to}` reads a long page in parts, `path` reads another text file of the version). Then `manage_brand` `action: edit_page` with `pageId`, `edits` (exact `old` text and its `new` text, up to 50, applied in order) and `expectedSha256`. If any edit does not match, nothing is saved and the error names it. A published version is kept and the edit becomes a new draft.
5. Check: `query_brand` `action: check_page` with `pageId` checks every file against the guide's rules. Blocking findings stop a publish; fix them with `edit_page`. For a render in a real browser, `manage_brand` `action: render_check` with `pageId` loads every page (8 at most) at phone and desktop size in a sandbox and reports errors, failed requests, layout shift, overflow, blank renders and slow loads with screenshots. It changes nothing, counts against 20 render checks per workspace per day, and takes a while; ask first, then read the result with `check_page`. Its findings are warnings, not a publish gate.
6. On yes, `manage_brand` `action: publish_page` with the `pageId` (or `create_page` or `edit_page` with `publish: true` when the user has already approved the result). Admin role. The edge is invalidated in the same call and the response carries the live URL.
7. `manage_brand` `action: revert_page` puts the default render back. Stored versions stay listed under `get_page` and can be published again. `action: delete_page` with `pageId` permanently deletes a version that is not live, such as an abandoned draft (admin; confirm first).

### More than one page

A version can hold more files than `index.html`: other pages (`events/index.html`), CSS, scripts, fonts and images.

1. `manage_brand` `action: create_version` (optional `basePageId`, default the published version) makes a draft copy with all its files.
2. `query_brand` `action: get_site` with `pageId` lists the files with their sizes and `sha256`.
3. `manage_brand` `action: put_files` with `pageId` and up to 20 `files` per call: `{path, content}` for text (HTML pages always this way), `contentBase64` for a binary file up to 1 MiB, `assetId` for an image or video already uploaded with `upload_asset`, or `siteAssetId` for a larger file (10 MiB at most): get it from `manage_brand` `action: create_file_upload` with `path` and `bytes`, then PUT the file to the returned `uploadUrl` with the headers given. A version holds 200 files and 25 MiB.
4. `manage_brand` `action: delete_files` with `pageId` and `paths` removes files from the draft (confirm first; `index.html` stays).
5. Check and publish as in steps 5 and 6. Only a draft can change; for a published version, make a new draft with `create_version` first.
