---
name: adapt
description: SparkleTree campaign adaptation command, /sparkletree:adapt [what should change, and when]. Turns a sentence like "each morning at 6 find the meme of the day and joke about it in the hero" into a concrete live change to a campaign, the brand page or the concierge, applied once now or on a schedule the host runs. Free writes only; every run reads before it writes and reports old versus new.
disable-model-invocation: true
argument-hint: "[what should change, and when]"
---

Adapt live SparkleTree behaviour to: $ARGUMENTS

If `$ARGUMENTS` is empty, ask for one sentence that names what should change and when. A good one has three parts: a trigger (now, every morning at 06:00, when it rains in Stockholm), a source (a web search, the weather, the day's news, a product feed, nothing), and a target (a campaign's copy, the brand page concierge, the brand voice, which variant is active).

Read `skills/sparkletree` first if it is not loaded. Its rules apply: read before write, confirm before any change, say who pays.

## 1. Resolve the target

Map the sentence to exactly one write and read its current state first:

| The user means | Read | Write |
|---|---|---|
| Campaign copy (kicker, headline, body, CTA, chips) | `query_campaigns` `action: variants` | `manage_campaigns` `action: update_variant` |
| Which variant runs | `query_campaigns` `action: variants` | `manage_campaigns` `action: update_variant` with `isActive` |
| Brand page answers, chips, facts, FAQ | `query_brand` `action: get` | `manage_brand` `action: update_concierge` |
| Brand voice, tagline, dos and donts | `query_brand` `action: get` | `manage_brand` `action: update_voice` or `update_brandbook` |
| The brand home page itself (an agent-authored page) | `query_brand` `action: get_page` | `manage_brand` `action: create_page` as a draft, then `publish_page` on approval; `revert_page` restores the default. See `skills/brand-voice-sync` section 6. |

Name the campaign or brand subtree by name and id and echo it back. Brand writes need the admin role; if the user is not an admin, prepare the text and hand it over instead. Never target `generate_campaign`, `render_video` or `video_commission` from this command: they spend credits and a scheduled run cannot answer the spend hook.

## 2. Resolve the source

If the sentence needs outside information (the internet's mood of the day, a trend, weather, a score), fetch it with the host's web search or fetch tool now, summarise it in one line, and keep that line in the report. If the host has no such tool, say so and offer the version that works without it (a fixed rotation, a day-of-week message). Do not invent the source.

## 3. Draft and check the change

Write the new text. Then check it against `query_brand` `action: get`: guidelines.contentRules and voice.donts are hard limits, and humour that leans on a person, a tragedy, a competitor or a protected group is out regardless. If the draft fails the check, keep the current text and report why. Show old versus new side by side and wait for a yes.

## 4. Apply once

On yes, make the single write from step 1. Saves republish automatically. Report the target, old text, new text and the page URL from `query_campaigns` `action: get`.

## 5. Make it recurring

If the sentence has a schedule, create it in the host after the first run is approved. Claude Code: `/schedule` (a routine). Claude.ai and Claude desktop: a scheduled task. ChatGPT: a scheduled task. Other hosts: tell the user the schedule has to live in a host that can run prompts on a timer, and give them the prompt.

The scheduled prompt must be self contained. Put in it: the workspace name, the target by name and id, the exact read and write calls, the source and how to fetch it, the content check from step 3, the rule that a failed check keeps the current text, and that each run ends with one line: date, source summary, old text, new text or "unchanged: reason". Tell the user the schedule runs under their account and role, changes nothing that costs credits, and stops when they delete the task or pause the campaign.

## Stop conditions

Stop and ask when the sentence maps to more than one target, when the source cannot be fetched, when the change would need a credit-spending tool, or when the draft fails the brand check and the user has not said what to do instead.
