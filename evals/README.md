# Evals

One case per model-invocable skill, plus `squid-templates` (the template library, graded on `squid-design`) and `brand-page` (brand page edits and a multi-page site, graded on `brand`), in the layout that Claude Code's plugin eval command reads: `<case>/prompt.md` (frontmatter plus the prompt) and `<case>/graders/*.md`. Each case has three graders: `tool_used` on the Skill tool for the expected skill, a `regex` on the final message for the confirmation or key terms, and an `llm` grader for read-before-write and confirm-before-spend.

Run: `claude plugin eval . --allow-tools Skill`. The plugin eval command is early access in Claude Code 2.1.257. Results land in `evals/results/`, which is ignored by git.

The prompts allow loading skills but forbid SparkleTree tools in the graded turn, so a run needs no SparkleTree account and spends no credits. (A prompt that forbids every tool also forbids the Skill tool, and the `tool_used` grader then fails even when the model picked the right skill.)

The session hook has its own check: `sh scripts/test-hooks.sh` runs `check-connector.sh` against a healthy and an unreachable server.
