---
name: launch
description: Launch a SparkleTree campaign end to end from a product URL or a goal. Brief for approval, generate, review, publish, live link.
disable-model-invocation: true
argument-hint: "[product URL or goal]"
---

Run the `sparkletree:launch-campaign` skill for: $ARGUMENTS

If `$ARGUMENTS` is empty, ask for a product URL or a one-sentence goal first. Follow the skill exactly: product, brief (stop for approval), generate, poll, review, publish and deploy (stop for approval), hand back the live URL. Report the campaign name, id, variant count, surface and URL, or the exact step and reason where it stopped.
