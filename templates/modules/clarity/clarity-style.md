# Clarity style (80% ASD-STE100)

> Installed by the `clarity` module. Apply to every assistant reply:
> chat, specs, reviews, progress notes.
> Goal: shorter, verifiable output. The full ASD-STE100 spec is too
> strict for interactive work — use this subset.

## Rules

1. One idea per sentence. Max 20 words. Split longer sentences.
2. Active voice. Name the actor: `The implementer runs X` beats
   `X is run`.
3. One term, one meaning. Do not swap `store` / `repository` /
   `adapter` mid-session. Reuse the repo's own vocabulary.
4. No filler. Never write `actually, basically, maybe, could,
   very, quite, fairly, possibly`. State the fact or the gap.
5. Procedures as numbered steps, one command per step. Put the
   green/red result at the end, not in the middle.
6. Soften on explanation, never on gates: plain language for
   prose, exact paths, line numbers and commands for evidence.

## Non-goals

- Not the full aerospace dictionary. Technical terms, code names
  and uncertainty stay when precision needs them.
- Never trade clarity for correctness: a clear wrong command is
  still wrong. Verify paths and test output as usual.

## References

- Andrej Karpathy, 2026-10-02: "Ask your LLM to explain something
  in ASD-STE100 ... Sometimes I've tried to soften it a bit e.g.
  ask for '80% of the way to ASD-STE100' because the spec is quite
  stringent." Plus the ladder: diagrams/images, then HTML pages,
  then bespoke explainer videos.
  https://x.com/karpathy/status/2105819303471976479
- Kun Chen (@kunchenguid), 2026-10-02, reply: tested the ASD-STE100
  wording rule, "surprisingly good at helping increase clarity of
  model response, even within html artifacts", but "the full
  ruleset is a bit too strict and you need to pick a subset". Prompt
  to mine your own subset from 10 recent transcripts into
  `AGENTS.md`.
  https://x.com/kunchenguid/status/2105931853815296295

## Origin

Subset mined 2026-10-05 from the last 10 local opencode sessions
(926 assistant blocks): median sentence 11 words, 16.6% over 20
words, top fillers `actually / should / maybe / could / might`,
~5% passive. These six rules target exactly that.
