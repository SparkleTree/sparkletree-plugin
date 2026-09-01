# Evals

One case per model-invocable skill, in the `claude plugin eval` layout: `<case>/prompt.md` (frontmatter plus the prompt) and `<case>/graders/*.md`. Each case has three graders: `tool_used` on the Skill tool for the expected skill, a `regex` on the final message for the confirmation or key terms, and an `llm` grader for read-before-write and confirm-before-spend.

Run: `claude plugin eval . --allow-tools Skill`. `plugin eval` is early access in Claude Code 2.1.257; if the command reports that, `evals/run-smoke.sh` runs the same prompts through `claude -p --plugin-dir .` and checks that the expected skill loaded. Results land in `evals/results/`, which is ignored by git.

The prompts ask the model not to call tools in the graded turn, so a run needs no SparkleTree account and spends no credits.
