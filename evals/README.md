# Evals

One case per model-invocable skill, plus `squid-templates` (the template library, graded on `squid-design`) and `brand-page` (brand page edits and a multi-page site, graded on `brand`), in the `claude plugin eval` layout: `<case>/prompt.md` (frontmatter plus the prompt) and `<case>/graders/*.md`. Each case has three graders: `tool_used` on the Skill tool for the expected skill, a `regex` on the final message for the confirmation or key terms, and an `llm` grader for read-before-write and confirm-before-spend.

Run: `claude plugin eval . --allow-tools Skill`. `plugin eval` is early access in Claude Code 2.1.257; if the command reports that, `evals/run-smoke.sh` runs the same prompts through `claude -p --plugin-dir .` and checks that the expected skill loaded. Results land in `evals/results/`, which is ignored by git.

The prompts allow loading skills but forbid SparkleTree tools in the graded turn, so a run needs no SparkleTree account and spends no credits. (A prompt that forbids every tool also forbids the Skill tool, and the `tool_used` grader then fails even when the model picked the right skill.)

Hook behaviour has its own check: `sh scripts/test-hooks.sh` feeds hook payloads through `spend-guard.sh`, `job-watch.sh` and `check-connector.sh`, once with jq and once with the sed fallback.
