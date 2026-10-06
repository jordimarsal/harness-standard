## 4. Workflow (SDD — mandatory for all features)

```
pending → [spec-author] → spec_ready → ⏈ HUMAN → in_progress → [implementer → reviewer] → done
```

1. The leader detects the first `pending` feature.
2. The leader dispatches `spec-author`, who creates `harness/specs/<name>/{requirements,design,tasks}.md` and marks status as `spec_ready`.
3. **Pause.** The human reads the spec at `harness/specs/<name>/` and approves (or requests changes).
4. Once approved, the leader changes status to `in_progress` and dispatches `implementer`.
5. The implementer executes `tasks.md` **one batch at a time**, marking each task `[x]` (see *Batching* below).
6. The reviewer verifies traceability `R<n>` ↔ test and task completion; approves or rejects.
7. The human reviewer confirms the Completion Gate (`docs/specs.md`). Only after that explicit human approval does the implementer create `harness/specs/<name>/APPROVAL` (human, date, gate), change status to `done`, and move the summary to `harness/progress/history.md`, adding one retro line under it: `retro: <n> dispatches · <s> stalls · <r> restarts` — count what you received for this feature (a stall is a `Nothing was written` re-dispatch; a restart is being re-dispatched in a fresh session).

### Batching (one dispatch = one batch)

The leader never hands a whole feature to a single implementer dispatch:

- A batch = **2–4 consecutive `T<n>` tasks** forming one coherent unit (a change plus its tests). Use 1 task when a single task is large (migration + repository + tests), 4 only when the tasks are small clones, **never 5+**.
- The dispatch names the batch, the first file to create and the gates to reach — nothing else. The protocol itself lives in `.opencode/agent/implementer.md` (or `.claude/agents/implementer.md`).
- After every batch the leader verifies **on disk** before dispatching the next one: tasks marked `[x]`, files really present, and the gates run **by the leader itself**. A subagent's chat claim is not evidence.
- Empty reply or missing files → the batch stalled: re-dispatch the **same** batch opened with `Nothing was written: <missing paths>. Create <first file> now.` Two stalls in a row → start a fresh subagent session; likewise start a fresh session once one approaches ~70% of its context window (a full context stops working silently).

### Parallelism

When `"parallel": true` in `harness/feature_list.json` project config:
- Independent tasks (no `depends_on`) can be dispatched to separate implementer subagents simultaneously.
- Only 1 feature may be `in_progress` at a time.

When `"parallel": false` (default): sequential execution, one task at a time.

