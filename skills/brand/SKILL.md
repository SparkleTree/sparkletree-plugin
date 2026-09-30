---
name: brand
description: SparkleTree brand book, voice and brand page. Set up or refresh logo, colours, fonts, tone, dos and donts, messaging and the concierge answers from a website or documents, and author or revert the brand home page. Use for import our brand, tone of voice, brand colours, brand guidelines, concierge, brand page, or onboarding a new SparkleTree workspace.
---

# Brand book, voice and brand page

The brand book is what every generated variant, Squid and page inherits. Get it right once and generation stays on voice; leave it empty and every campaign starts from nothing.

Brand writes need the admin role (a workspace API key counts as a member and cannot make them). The one exception is a brand home page draft, which a member can store. Check with `get_platform_info` `topic: "organization"`; if the user is not an admin, prepare the content and hand it over instead of calling `manage_brand`.

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

Logo and imagery are stored as links. Use a link the brand controls, or put the file in the workspace first with `upload_asset` and use the returned `asset.url`.

Keep everything factual. The concierge answers visitors on the public brand page; anything written here is said to customers.

## 4. Write, subtree by subtree

After the user approves, write only the subtrees you changed. Writes merge per subtree: what you send replaces that subtree, what you omit is preserved.

- `manage_brand` `action: update_brandbook` with `brandAssets` (logo, colors, fonts, imagery) and `brandGuidelines` (voice, messaging, contentRules)
- `manage_brand` `action: update_profile` with `profile`
- `manage_brand` `action: update_voice` with `voice` (eyebrow, tagline, headingFont, bodyFont, tone)
- `manage_brand` `action: update_concierge` with `concierge` (chips, inputHint, language, assistant, hideCampaigns)

Edge caches invalidate in the same call. Published campaign pages bake visuals at publish time; if colours or the logo changed, republish the affected campaigns with `manage_campaigns` `action: publish` (confirm first). Existing variants keep the colour scheme they inherited.

## 5. Verify

`query_brand` `action: get` again and read the result back in two lines. If the brand page is published, its `/llms.txt` and `/ask` now answer with the new facts; suggest one test question.

## 6. The brand home page, if the user wants it authored

The brand host (`<slug>.sparkletree.io` or the custom domain) renders a default home page from the brand book. An agent can replace it with one hand-authored HTML document. Only do this when the user asks for it; the default render is fine for most workspaces.

1. `query_brand` `action: get_page`: the live state, every stored version with its preview URL, and the agent guide. The same guide is the resource `mosaic://brand-page-guide`. Read it before writing: it carries the palette, the live campaign ids, the relative embed and link paths the edge serves, and the rules.
2. Write one complete, self-contained HTML document (doctype to closing html tag, 1 MiB at most). Use only the paths the guide names for campaign embeds and links; nothing external that the page cannot live without.
3. `manage_brand` `action: create_page` with `html` and a short `notes` line. Without `publish` it stores a draft and returns a signed preview URL on the real host; the member role is enough for a draft. Show the user the preview URL and wait.
4. On yes, `manage_brand` `action: publish_page` with the `pageId` from the draft (or `create_page` with `publish: true` when the user has already approved the HTML). Admin role. The edge is invalidated in the same call and the response carries the live URL.
5. `manage_brand` `action: revert_page` puts the default render back. Stored versions stay listed under `get_page` and can be published again.
