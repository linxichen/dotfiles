# Ting Zhou's Orca orchestration preferences

These personal defaults apply when coordinating or participating in supervised
Orca work. A direct instruction for the current task can override them. Orca's
orchestration guide (`orca skills get orchestration` and the references it
names) owns the mechanics and the safety floor; this file owns roles, model
choice, capacity limits and quota recovery. Where the two seem to conflict on
mechanics, follow Orca's guide and report the conflict to the user. Keep project
rules and task state in their own homes.

## Roles: one hub, many spokes

### The coordinator is the hub

- The coordinator is whichever session holds the Run: it created the Run with
  `run-create` or bound it with `run-use`. It is usually the session the user
  started, and may be any model, typically an always-on one such as dsh-tui.
  Run it inside an Orca terminal so Orca can identify it as the caller.
- The coordinator's jobs are:
  - talking with the user, in clear and non-defensive language, about plans,
    designs, progress and decisions that the workers produced;
  - writing self-contained Task specs, dispatching and sequencing workers;
  - administration: checkpoints, issue closure and moving to the next ticket;
  - rescue: detecting a failed or stalled worker, running quota recovery,
    and handing the work to the next model (see "Worker failure, rescue and
    fallback");
  - accepting work, based on an independent review's evidence.
- The coordinator does not do the heavy work itself: no planning, design,
  debugging, implementation or substantive review. It may read outputs to
  route and summarize them. A review result authorizes the coordinator to
  summarize findings, not to edit files: dispatch the fixes to a worker. During
  a rescue, it hands the unfinished work to a worker rather than finishing it.
  The user can assign a specific piece of work to the coordinator explicitly.
- A coordinator handoff moves the Run to a new coordinator. The new session
  binds the existing Run with `run-use` from its own Orca terminal, and only
  after the old coordinator has stopped coordinating; two coordinators never
  drive one Run at once. The handoff note names the Run ID, the open Tasks and
  their checkpoints, and this policy's path with a requirement to read it.

### Workers are the spokes

- The coordinator is the only channel between the user and the workers.
  Workers put questions to the coordinator with Orca `ask` and raise blockers
  as escalations; they never open a local prompt for the user. The coordinator
  relays owner decisions to the user and replies with the answer.
- Workers do not coordinate with each other directly. Anything one worker
  produces for another goes through the coordinator, as files or report paths
  named in the next Task spec.
- A worker may start Orca helper workers only when its Task spec allows it. The
  parent worker answers its helpers, stays accountable for their output and
  waits for all of them before its own `worker_done`. Helpers never contact the
  user and count toward every capacity limit below.
- If the user gives a worker an instruction directly, the instruction stands.
  The worker reports it to the coordinator: in its `worker_done` summary, or as
  an escalation if it changes the Task's scope.

### Settlement is not acceptance

A valid `worker_done` settles the Task and Dispatch in Orca; that is
bookkeeping. Acceptance is the coordinator's later decision, and issue closure
and the next dependent ticket wait for it. A worker's completion report is
evidence for review, not acceptance.

## Routing work to models

- Flagship models do the heavy work as workers: planning, architecture and
  design, debugging, independent review and hard multi-step mathematical
  problem-solving. Run them at high effort or above.
- Workhorse models do implementation, routine research and edits, usually
  against a plan or design a flagship produced.
- Final independent review uses a flagship model at xhigh effort and checks the
  work against both the repository standards and the originating issue or
  specification. The reviewer is a fresh session that did not author the work
  and receives only the spec, the standards and the change. When a flagship
  wrote the work, prefer the other flagship's model family as reviewer.
- Order tickets by dependencies and run independent work in parallel when it
  helps and is authorized. Continue within the user's authorized scope without
  routine confirmations; keep explicit owner decision gates.
- Verify the model and effort actually running; a harness name alone does not
  establish them. For an Orca launch, compare `launch.effective` with
  `launch.requested`. Orca cannot set the model or effort for some launches
  (ZCode, terminals started with `--terminal` such as dsh-tui, and effort for
  omp): set those in the harness's own configuration or flags, then confirm
  from its screen or status bar.
- Supervised work uses Orca workers; never substitute a non-Orca subagent tool.
- Every Task spec is self-contained and follows Orca's spec contract (target,
  change, constraints, ownership, observable acceptance). Include this policy's
  absolute path and a requirement to read it in every worker brief and
  coordinator handoff. For a remote worker that cannot read this file, include
  the relevant policy text. Child sessions do not inherit the coordinator's
  context.

## Capacity and concurrency

- Check remaining usage before a parallel wave: `orca account list --json`
  (`result.rateLimits`) for Claude and Codex, and ZCode's Usage stats for GLM.
- The Opus flagship and the Sonnet workhorse share one Claude subscription, as
  does a coordinator running on Claude. Keep at most one or two heavy Claude
  workers running at once. Put parallel fan-out on GLM first, then the local
  cluster within its cap, then Codex.
- **Local models: at most 4 concurrent requests.** This limit covers
  GLM-5.3Flash-EXL3 and any future model served from the homelab cluster,
  counted across every Run and session using it, helpers included. Beyond 4,
  prefill becomes extremely slow and the service can hang. Orca does not
  enforce this limit, so the coordinator does: count active local workers
  before each start and keep further local Tasks waiting until a slot frees. A
  worker that issues parallel requests (subagents, parallel tool calls) counts
  once per concurrent request. Give the local cluster fresh tasks rather than a
  large existing session, because cold prefill of a big context is slow.
- Release settled workers promptly, following Orca's completion accounting.

## Worker failure, rescue and fallback

The coordinator runs this procedure; a worker that has hit a limit often cannot
report anything itself. Detect trouble from `worker-list` attention, liveness
and `worker-read` output. A timeout, an unchanged screen or other absence of
signal is not proof of failure.

1. **Classify the failure.** Quota exhaustion, a provider or server error with
   quota still available, and an agent crash or stall each have a different
   response. A server error with quota available is an availability failure:
   do not consume a quota reset to troubleshoot it.
2. **Preserve the work.** Keep the Dispatch, its worktree and the work
   checkpoint: what is done, what remains, and the paths involved. Record it in
   the run's checkpoint, not in this policy.
3. **Recover in place when possible.** For an exhausted GLM quota, run the GLM
   procedure below and resume the same Dispatch; recovering in place is not a
   retry. For an exhausted Claude or Codex quota, wait for the reset when the
   timing allows.
4. **Otherwise fall back under Orca's safety floor.** Start a new attempt only
   after positive proof that the old one failed or stopped: a
   `worker_done --outcome failed`, proven `exited` liveness, or a transcript
   whose final agent turn sent no `worker_done`. Then settle it with
   `worker-stop` or `worker-abandon` and start the replacement with
   `worker-start --task <task_id> --retry-of <dispatch_id>` on the next
   available model, with the checkpoint in its brief. Never run two editors on
   the same Task. After three failed starts Orca fails the Task: report it to
   the user rather than routing around it.
5. **Stand down the old worker.** Fencing a Dispatch does not stop an external
   terminal. Send the old worker an explicit stand-down, and after any Orca
   restart read every retained worker terminal before launching paid or
   persistent steps.
6. **Record the outcome.** Record the recovery result or the reason for the
   fallback in the run's checkpoint, not as quota balances or session IDs in
   this policy.

### GLM quota recovery before fallback

When a GLM/ZCode worker hits a usage limit, the coordinator:

1. Preserves the current session, Task/Dispatch and work checkpoint.
2. Uses native computer use to open the ZCode app's Usage stats and refresh the
   quota status, checking both the five-hour and weekly quota and reset
   controls.
3. Uses an available existing reset applicable to the exhausted quota before
   handing the task to another model. The user has authorized using these
   resets; purchasing additional resets requires separate authorization.
4. Refreshes Usage stats and verifies that an actual GLM request succeeds, then
   resumes the preserved work. A successful UI click alone is insufficient.
5. Falls back only when no applicable reset is available or the reset does not
   restore usage. If computer use cannot establish availability, it reports
   that limitation rather than claiming that no resets remain.

## Model and harness designations

"Latest" means the newest model the harness offers at launch; the examples
below were current in October 2026.

- Flagship models, in preferred order:
  1. Latest Opus via Claude Code (e.g. Opus 5.5).
  2. Latest Astra via Codex (e.g. GPT 6 Astra).

- Workhorse models, in preferred order:
  1. Latest Sonnet via Claude Code (e.g. Sonnet 5.5).
  2. Latest GLM at max effort via ZCode (e.g. GLM 5.3).
  3. Local model on Ting's homelab DGX Spark cluster via omp (e.g.
     GLM-5.3Flash-EXL3 under the vllm provider). It is free but has low
     concurrency: respect the 4-request cap above and prefer fresh tasks.
  4. Latest Sol at xhigh effort via Codex (e.g. GPT 6.1 Sol). Deprioritized to
     reduce use of the ChatGPT subscription. Use it mainly when the local
     cluster is unsuitable, such as taking over a large existing session.
  5. Stopgap only: latest DeepSeek Flash via omp or dsh-tui (deepseek-harness),
     because it bills per API call.
