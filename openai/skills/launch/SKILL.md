---
name: launch
description: SparkleTree campaign launch command, the sparkletree launch skill <product URL or goal>. Runs the launch-campaign skill end to end with the argument as the starting point, shows the brief for approval before generating, and finishes with a live campaign URL or a clear reason it stopped.
---

Run the `sparkletree:launch-campaign` skill for: the user's request

If `the user's request` is empty, ask for a product URL or a one-sentence goal first. Follow the skill exactly: product, brief (stop for approval), generate, poll, review, publish and deploy (stop for approval), hand back the live URL. Report the campaign name, id, variant count, surface and URL, or the exact step and reason where it stopped.
