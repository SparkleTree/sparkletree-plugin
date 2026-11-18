# Live stream and commentary over a custom design

A campaign can route a live stream to the places its Squid shows on, and turn live commentary on for that stream. A custom design says in its manifest where both go, under `capabilities` next to `chat`. The `agentGuide` from `query_campaigns` `action: get_component` is the full reference; this file repeats the rules and gives three complete designs, one per placement.

## The two fields

- `live`: where the stream plays over the design.
  - `inset` (the default): the player sits above the design in the top-right corner, across the top on a tall frame. It works over any design.
  - `main`: the stream is the main picture. The player takes the largest 16:9 box that fits the frame (the whole frame on a 16:9 screen, across the top of a tall frame, on the left of a banner) and sits under the design, which draws over it.
  - `box`: the player sits exactly over the design's first element marked `data-live`. Until that box is known, when there is no such element and when the box is too small, the player uses the `inset` box.
  - `none`: no stream over this design, and no commentary.
- `commentary`: where live commentary shows when the campaign has it on and the stream plays.
  - `standard` (the default): the page draws it next to the player.
  - `own`: the design shows it, in elements marked `data-commentary`, and gets `commentary` events.
  - `none`: no commentary over this design.

A design made before these fields existed shows a routed stream in the corner.

## What the design is told

`sparkletree.layout`, and the `layout` event, is `{ live, on, liveRect, commentary, commentaryRect, free }`:

- `live` is the design's mode, `on` whether a stream plays now.
- `commentary` is `standard`, `own` or `none` (`none` also when the campaign's commentary is off).
- `liveRect` is the player's box, `commentaryRect` the box where the page draws the commentary (only with `standard`), and `free` (only with `main`) the area the stream and the commentary leave for the design's own copy. Boxes are `{ x, y, w, h }` in the frame's CSS px, or `null`.
- The boxes are worked out as if the stream were playing, so nothing moves when it starts.
- The first layout arrives right after `init`; later ones after a resize and when a box or `on` changes. A handler added late still gets the current one. The `live` event is `{ on }` when the stream starts or stops.

The root element carries the same values, so the layout can be CSS only: `data-st-live="on"` or `"off"`, `data-st-live-mode`, `data-st-free` (present when there is a `free` box), and `--st-live-x`, `--st-live-y`, `--st-live-w`, `--st-live-h`, the same four for `--st-commentary-` and `--st-free-`, in px (`0px` for a box there is none of). Without a layout none of them is set.

`data-commentary` elements fill like standard slots: `start` empties them, each `chunk` appends, `done` sets the final text. An empty `done` means the line failed or was cut off. Lines are at least 20 s apart.

## Rules

- `main`: keep the document background transparent only while `data-st-live="on"`; with the stream off, show the full creative. Put the copy in the `free` box when there is one, else over the lower part of the stream.
- `inset`: keep copy out of the player's box, and out of the commentary box, while a stream plays.
- `box`: the `data-live` element is 16:9, at least 80×45 px, inside the frame, and never moves or animates. Nothing can be drawn over it. It needs a plain look of its own for when no stream plays. The player takes its top-left corner radius. A box cut to the frame that ends up under 80×45 px falls back to the inset box.
- A player over the design is never under 80×45 px. On a frame too small for one, such as a 90 px strip, `liveRect` is `null` even when `on` is true. Lay out for the stream only when `liveRect` is set.
- Reserve the space of a `data-commentary` element, so a line that comes or goes moves nothing.
- Never wait for the stream or a layout before `ready()`. The design check and the dashboard previews play no stream (the layout arrives with `on: false`), and a video export has no layout at all, so the design must look finished without either.

The examples below set `chat: "none"` to stay short. With `chat: "standard"`, also keep the chat bar's band along the bottom free of text and controls.

## Example: main

A transparent design: the full poster while the stream is off; with it on, the copy in the `free` box when there is one, else over the lower half of the stream. The layout is CSS only.

```json
{
  "v": 1,
  "slots": [
    { "source": "standard", "name": "headline" },
    { "source": "standard", "name": "body" },
    { "source": "standard", "name": "cta" },
    { "source": "custom", "name": "brand_name", "kind": "text", "label": "Brand name", "maxLength": 60 }
  ],
  "capabilities": { "chat": "none", "live": "main", "commentary": "standard" }
}
```

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Live example: main</title>
<style>
  :root {
    --brand-bg: #0f1420;
    --brand-surface: #22335c;
    --brand-ink: #f4f1ea;
    --brand-accent: #ffd84a;
    --brand-accent-2: #8fb3ff;
    --brand-font-display: Georgia, "Times New Roman", serif;
    --brand-font-body: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  /* The stream is the picture: it plays under this document, so the
     document is see-through only while the stream is on. */
  html, body { margin: 0; height: 100%; overflow: hidden; background: var(--brand-bg); }
  html[data-st-live="on"], html[data-st-live="on"] body { background: transparent; }
  body { color: var(--brand-ink); font: 16px/1.4 var(--brand-font-body); }

  /* Stream off (and wherever there is no layout): the full poster. */
  .poster {
    position: fixed; inset: 0;
    background: radial-gradient(120% 90% at 100% 0, var(--brand-surface), var(--brand-bg) 70%);
  }
  html[data-st-live="on"] .poster { visibility: hidden; }

  .copy {
    position: fixed; inset: 0; box-sizing: border-box;
    display: flex; flex-direction: column; justify-content: flex-end; align-items: flex-start;
    padding: 6vmin;
  }
  .copy > * { max-width: min(36em, 70%); }
  /* Stream on, no free box: the copy over the lower half of the stream. */
  html[data-st-live="on"] .copy {
    inset: auto;
    left: var(--st-live-x); top: calc(var(--st-live-y) + var(--st-live-h) / 2);
    width: var(--st-live-w); height: calc(var(--st-live-h) / 2);
    padding: 16px 20px;
    background: linear-gradient(transparent, color-mix(in srgb, var(--brand-bg) 85%, transparent) 60%);
  }
  /* Stream on and a free box: the copy there, on the brand background. */
  html[data-st-live="on"][data-st-free] .copy {
    left: var(--st-free-x); top: var(--st-free-y);
    width: var(--st-free-w); height: var(--st-free-h);
    justify-content: center;
    background: var(--brand-bg);
  }

  .brand { margin: 0 0 .5em; font-size: 12px; font-weight: 700; letter-spacing: .12em;
           text-transform: uppercase; color: var(--brand-accent-2); }
  .brand:empty { display: none; }
  h1 { margin: 0; font: 700 clamp(22px, 5vmin, 56px)/1.05 var(--brand-font-display); text-wrap: balance; }
  [data-slot="body"] { margin: .5em 0 0; opacity: .85; }
  button { margin-top: .8em; padding: .6em 1.2em; border: 0; border-radius: 999px; cursor: pointer;
           font: 700 14px/1 var(--brand-font-body); background: var(--brand-accent); color: var(--brand-bg); }
  button:focus-visible { outline: 3px solid var(--brand-ink); outline-offset: 3px; }
</style>
</head>
<body>
<div class="poster" aria-hidden="true"></div>
<main class="copy">
  <p class="brand" data-slot="brand_name"></p>
  <h1 data-slot="headline"></h1>
  <p data-slot="body"></p>
  <button type="button" id="cta" data-st-cta><span data-slot="cta">Learn more</span></button>
</main>
<script>
  var st = window.sparkletree;
  // Open the link inside the click handler itself (keeps the user activation).
  document.getElementById("cta").addEventListener("click", function () { st.cta(); });
  // The layout is all CSS (data-st-live, data-st-free, --st-live-*, --st-free-*).
  // Never wait for the stream: ready as soon as the first frame is settled.
  document.fonts.ready.then(function () { st.ready(); });
</script>
</body>
</html>
```

## Example: inset

An ordinary opaque design. While a stream plays it keeps its copy out of the player's corner with the `--st-live-` properties, and out of the commentary box with the `--st-commentary-` ones. A small `layout` handler marks the root only when those boxes exist.

```json
{
  "v": 1,
  "slots": [
    { "source": "standard", "name": "headline" },
    { "source": "standard", "name": "body" },
    { "source": "standard", "name": "cta" },
    { "source": "custom", "name": "brand_name", "kind": "text", "label": "Brand name", "maxLength": 60 }
  ],
  "capabilities": { "chat": "none", "live": "inset", "commentary": "standard" }
}
```

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Live example: inset</title>
<style>
  :root {
    --brand-bg: #0f1420;
    --brand-surface: #22335c;
    --brand-ink: #f4f1ea;
    --brand-accent: #ffd84a;
    --brand-accent-2: #8fb3ff;
    --brand-font-display: Georgia, "Times New Roman", serif;
    --brand-font-body: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  /* An ordinary opaque design. The player floats above it in the top-right
     corner (across the top on a tall frame) while a stream plays. */
  html, body { margin: 0; height: 100%; overflow: hidden; }
  body { color: var(--brand-ink); font: 16px/1.4 var(--brand-font-body);
         background: radial-gradient(120% 90% at 100% 0, var(--brand-surface), var(--brand-bg) 70%); }

  .copy {
    position: fixed; inset: 0; box-sizing: border-box;
    display: flex; flex-direction: column; justify-content: flex-end; align-items: flex-start;
    padding: 6vmin;
  }
  .copy > * { max-width: 36em; }

  /* Keep the copy out of the player's box, and out of the platform's
     commentary box when there is one. data-player and data-player-talk are
     set by the script below, only when that box exists. */
  @media (min-aspect-ratio: 1/1) {
    html[data-player] .copy > * { max-width: min(36em, calc(var(--st-live-x) - 12vmin)); }
    html[data-player-talk] .copy > * {
      max-width: min(36em, calc(min(var(--st-live-x), var(--st-commentary-x)) - 12vmin));
    }
  }
  @media (max-aspect-ratio: 999/1000) {
    html[data-player] .copy { padding-top: calc(var(--st-live-y) + var(--st-live-h) + 4vmin); }
    html[data-player-talk] .copy {
      padding-top: calc(max(var(--st-live-y) + var(--st-live-h), var(--st-commentary-y) + var(--st-commentary-h)) + 4vmin);
    }
  }

  .brand { margin: 0 0 .5em; font-size: 12px; font-weight: 700; letter-spacing: .12em;
           text-transform: uppercase; color: var(--brand-accent-2); }
  .brand:empty { display: none; }
  h1 { margin: 0; font: 700 clamp(22px, 5vmin, 56px)/1.05 var(--brand-font-display); text-wrap: balance; }
  [data-slot="body"] { margin: .5em 0 0; opacity: .85; }
  button { margin-top: .8em; padding: .6em 1.2em; border: 0; border-radius: 999px; cursor: pointer;
           font: 700 14px/1 var(--brand-font-body); background: var(--brand-accent); color: var(--brand-bg); }
  button:focus-visible { outline: 3px solid var(--brand-ink); outline-offset: 3px; }
</style>
</head>
<body>
<main class="copy">
  <p class="brand" data-slot="brand_name"></p>
  <h1 data-slot="headline"></h1>
  <p data-slot="body"></p>
  <button type="button" id="cta" data-st-cta><span data-slot="cta">Learn more</span></button>
</main>
<script>
  var st = window.sparkletree;
  var root = document.documentElement;
  document.getElementById("cta").addEventListener("click", function () { st.cta(); });
  // The first layout arrives right after init; later ones after a resize or
  // when the stream starts or stops. On a frame too small for a player,
  // liveRect is null even while on is true, so test the box itself.
  st.on("layout", function (layout) {
    var player = !!(layout && layout.on && layout.liveRect);
    root.toggleAttribute("data-player", player);
    root.toggleAttribute("data-player-talk", player && !!layout.commentaryRect);
  });
  document.fonts.ready.then(function () { st.ready(); });
</script>
</body>
</html>
```

## Example: box, with its own commentary

The design marks the player's place with `data-live` and shows the commentary in a `data-commentary` line under it. Neither needs a script.

```json
{
  "v": 1,
  "slots": [
    { "source": "standard", "name": "headline" },
    { "source": "standard", "name": "body" },
    { "source": "standard", "name": "cta" },
    { "source": "custom", "name": "brand_name", "kind": "text", "label": "Brand name", "maxLength": 60 }
  ],
  "capabilities": { "chat": "none", "live": "box", "commentary": "own" }
}
```

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Live example: box</title>
<style>
  :root {
    --brand-bg: #0f1420;
    --brand-surface: #1b2233;
    --brand-ink: #f4f1ea;
    --brand-accent: #ffd84a;
    --brand-accent-2: #8fb3ff;
    --brand-font-display: Georgia, "Times New Roman", serif;
    --brand-font-body: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  html, body { margin: 0; height: 100%; overflow: hidden; }
  body { background: var(--brand-bg); color: var(--brand-ink); font: 16px/1.4 var(--brand-font-body); }

  /* Two columns on a wide frame, stacked on a tall one. The top padding of
     the stacked layout keeps the platform's disclosure corner clear. */
  .wrap { position: fixed; inset: 0; box-sizing: border-box; display: flex; align-items: center;
          gap: 32px; padding: 16px 40px; }
  .side { flex: 0 0 56%; min-width: 0; }
  .text { min-width: 0; }
  @media (max-aspect-ratio: 6/5) {
    .wrap { flex-direction: column; align-items: stretch; justify-content: center; padding: 76px 16px 16px; }
    .side { flex: none; }
  }

  /* The player's place: 16:9, fixed in place, never animated. The player
     covers it exactly (with its 8 px corners) while a stream plays; when
     none plays this plain panel shows. */
  .screen { width: 100%; aspect-ratio: 16 / 9; border-radius: 8px; background: var(--brand-surface); }

  /* The commentary line, under the player. Its space is always reserved,
     so a line that comes or goes moves nothing. */
  .talk { margin: 10px 0 0; min-height: 2.8em; font-size: 14px; line-height: 1.4; opacity: .85; }
  html:not([data-st-live="on"]) .talk { visibility: hidden; }

  .brand { margin: 0 0 .5em; font-size: 12px; font-weight: 700; letter-spacing: .12em;
           text-transform: uppercase; color: var(--brand-accent-2); }
  .brand:empty { display: none; }
  h1 { margin: 0; font: 700 clamp(22px, 4.5vmin, 48px)/1.05 var(--brand-font-display); text-wrap: balance; }
  [data-slot="body"] { margin: .5em 0 0; opacity: .85; }
  button { margin-top: .8em; padding: .6em 1.2em; border: 0; border-radius: 999px; cursor: pointer;
           font: 700 14px/1 var(--brand-font-body); background: var(--brand-accent); color: var(--brand-bg); }
  button:focus-visible { outline: 3px solid var(--brand-ink); outline-offset: 3px; }
</style>
</head>
<body>
<div class="wrap">
  <div class="side">
    <div class="screen" data-live aria-hidden="true"></div>
    <p class="talk" data-commentary aria-live="polite"></p>
  </div>
  <main class="text">
    <p class="brand" data-slot="brand_name"></p>
    <h1 data-slot="headline"></h1>
    <p data-slot="body"></p>
    <button type="button" id="cta" data-st-cta><span data-slot="cta">Learn more</span></button>
  </main>
</div>
<script>
  var st = window.sparkletree;
  document.getElementById("cta").addEventListener("click", function () { st.cta(); });
  // [data-live] and [data-commentary] work with no script: the platform
  // measures the first, and fills the second line by line.
  document.fonts.ready.then(function () { st.ready(); });
</script>
</body>
</html>
```
