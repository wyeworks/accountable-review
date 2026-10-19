// progress.ts — the e2e progress board (skills/review-map/evals/e2e/progress.rb), as one status
// line in Claude Code while /accountable-review:review-map runs interactively.
//
//   🌔 review map  ▕███████████▍       ▏  47%  11:02 / ~23:30  🔎 tracing consumers  🔧 38  🥊 4  📄 2/4  🪙 3.12M  ⏳ 5h +6%
//
// Every field is READ, never guessed, and that is the rule this file keeps: a progress line that
// invents progress is the verification badge of the terminal, and the page itself is forbidden
// that badge. Three sources, each one the engine or the run already produces:
//
//   * engine events — asking for the skill starts the run, each main-loop tool call names the
//     activity through hooks/activity.json (the table progress.rb reads too), each claim-falsifier
//     spawn is counted, and the coverage gate passing then the turn answering ends the run;
//   * the page the run is staging — checkpoints written against pending ones;
//   * the clock, against the median of this repository's earlier generations of the same kind,
//     which this file records itself. With none recorded there is no bar, only elapsed time;
//   * what the run spent: every model request's usage as the API reported it, the falsifiers'
//     requests included, and the account's 5-hour window as the engine measures it, from the
//     run's first reading. When the run ends the transcript gets one line with the breakdown.
//
// The activity is the latest tool call by purpose, never a step number: steps interleave and
// cannot be read off a run (evals/README.md § Profiling one run), and this does not pretend
// otherwise. It observes and nothing else — every hook passes its event on unchanged, and every
// one has a .catch that still does, so a bug in the line can never stall a generation.

import type { EngineInterface, Register, Timer } from 'claude-code'

import {
  type Activity,
  type Limit,
  type Usage,
  type RunKind,
  type Vars,
  assignedW,
  checkpoints,
  label,
  line,
  median,
  moved,
  NO_USAGE,
  addUsage,
  spent,
  totalTokens,
  outputPage,
  pagePath,
  parseActivity,
  repoKey,
  runKind,
  runsGate,
  summary,
} from './board'

const REVIEW_MAP = /(^|:)review-map$/
const FALSIFIER = /(^|:)claim-falsifier$/
const KEEP = 20 // generations remembered per repository and kind

type Run = {
  started: number
  paused: number // milliseconds spent waiting between turns, which are not generation
  waitingSince?: number
  ended?: 'done' | 'stopped' | 'interrupted'
  endedAt?: number
  activity?: string
  tools: number
  falsifiers: number
  page?: string
  vars: Vars
  checkpoints?: string
  sawGate: boolean
  kind: RunKind
  eta?: number
  repo?: string
  tick: number
  timer?: Timer
  usage: Usage
  falsifierUsage: Usage
  falsifierIds: Set<string>
  firstLimits: Limit[] // each window's first reading inside this run
  lastLimits: Limit[]
}

// The module's own variables start over on a reload, as register runs again.
let table: Activity = []
let run: Run | undefined

function elapsedMs(r: Run, now: number) {
  return (r.endedAt ?? r.waitingSince ?? now) - r.started - r.paused
}

const FIVE_HOUR = 'five_hour'

async function draw($: EngineInterface) {
  if (!run) return
  const now = await $.clock.now()
  const at = (ls: Limit[]) => ls.find(l => l.kind === FIVE_HOUR)
  $.ui.status(line({
    ...run,
    waiting: run.waitingSince !== undefined,
    elapsed: elapsedMs(run, now) / 1000,
    tokens: totalTokens(run.usage),
    window: moved(at(run.firstLimits), at(run.lastLimits)),
  }))
}

// A window's first reading inside the run is its baseline. A fresh session has no reading before
// its first response, so there the baseline is the first response's: the share is then short by
// at most one request, never padded. A window that resets mid-run keeps its old baseline, so it
// shows no share at all rather than the part since the reset.
function measured(r: Run, limits: readonly Limit[]) {
  for (const l of limits) {
    if (!r.firstLimits.some(f => f.kind === l.kind)) r.firstLimits = [...r.firstLimits, { ...l }]
  }
  if (limits.length > 0) r.lastLimits = limits.map(l => ({ ...l }))
}

async function readLimits($: EngineInterface): Promise<Limit[]> {
  try {
    return [...(await $.session.usage()).rateLimits]
  } catch {
    return [] // no reading is no reading: the line shows tokens alone
  }
}

async function recount($: EngineInterface) {
  if (!run?.page) return
  try {
    run.checkpoints = checkpoints(await $.fs.read(run.page))
  } catch {
    // a page mid-Edit or not written yet: the next page-touching call will have it
  }
}

function tick($: EngineInterface, r: Run) {
  r.timer?.cancel()
  r.timer = $.clock.every(1000, () => {
    r.tick += 1
    void draw($)
  })
}

function historyKey(repo: string, kind: RunKind) {
  return `generations:${kind}:${repo}`
}

// The command as typed, or as the engine records a typed skill command; a sentence that merely
// mentions review-map is not a request for one.
function isCommand(text: string) {
  return /(^\s*|<command-name>)\/(accountable-review:)?review-map(?=\s|<|$)/.test(text)
}

async function start($: EngineInterface, command: string) {
  run?.timer?.cancel()
  if (table.length === 0) {
    table = parseActivity(await $.fs.read(`${$.plugin.root}/hooks/activity.json`))
  }
  const kind = runKind(command)
  const repo = await $.session.repo()
  const key = repo ? repoKey(repo.remote, repo.root) : undefined
  const past = key ? await $.store.get(historyKey(key, kind)) : undefined
  const mine: Run = {
    started: await $.clock.now(),
    paused: 0,
    tools: 0,
    falsifiers: 0,
    sawGate: false,
    kind,
    page: outputPage(command),
    vars: { TMPDIR: await $.env.get('TMPDIR') },
    tick: 0,
    repo: key,
    eta: Array.isArray(past) ? median(past.filter((n): n is number => typeof n === 'number')) : undefined,
    usage: NO_USAGE,
    falsifierUsage: NO_USAGE,
    falsifierIds: new Set(),
    firstLimits: [],
    lastLimits: [],
  }
  measured(mine, await readLimits($))
  run = mine
  tick($, mine)
  await draw($)
}

export const register: Register = on => {
  table = []
  run = undefined

  // A run starts where the skill is asked for, in one of the two ways a person or the model can ask:
  // the command typed as a prompt, or a Skill tool call naming it. `skill.prompt` would be the
  // obvious event and is not one this mod can use: the engine's own security module sends it
  // beneath the user tier, so a plugin's hook on it never runs (the debug log says "skill.prompt
  // bypassed by cc-plugin-sec-default").
  //
  // A prompt typed over a running turn (`turnId`) is a note to that turn, not a new run. Any new
  // prompt takes down the line a finished run left standing.
  on('prompt.submit', async ($, e, next) => {
    if (run?.ended) {
      run = undefined
      $.ui.status(undefined)
    }
    if (e.turnId === undefined && isCommand(e.text)) await start($, e.text)
    return next(e)
  }).catch(($, e, next) => next(e))

  // The main loop only: progress.rb reads the parent transcript, and a falsifier's own reads are
  // its work, not the run's activity. Its spawn is what gets counted, below.
  on('tool.call', async ($, e, next) => {
    if (e.agentId !== undefined) return next(e)
    const args = e as unknown as Record<string, unknown>
    const asked = e.tool === 'Skill' && REVIEW_MAP.test(String(args.skill ?? ''))
    if (asked && (!run || run.ended)) {
      await start($, `/review-map ${String(args.args ?? '')}`)
      return next(e)
    }
    if (!run || run.ended) return next(e)
    const mine = run
    const text = summary(args)
    mine.tools += 1
    mine.activity = label(table, text) ?? mine.activity
    if (typeof args.command === 'string') mine.vars.W = assignedW(args.command, mine.vars) ?? mine.vars.W
    mine.page = pagePath(args, mine.vars) ?? mine.page
    await draw($)
    const result = await next(e)
    // Passing, not mentioning: the gate exits non-zero when the inventory and the diff disagree.
    if (runsGate(args) && result.deny === undefined && result.isError !== true) mine.sawGate = true
    if (mine.page && /page-skeleton\.sh|\.html\b/.test(text)) {
      await recount($)
      await draw($)
    }
    return result
  }).catch(($, e, next) => next(e))

  on('agent.spawn', async ($, e, next) => {
    const mine = run && !run.ended && FALSIFIER.test(e.subagentType) ? run : undefined
    if (mine) {
      mine.falsifiers += 1
      await draw($)
    }
    const result = await next(e)
    if (mine && result.agentId) mine.falsifierIds.add(result.agentId)
    return result
  }).catch(($, e, next) => next(e))

  // Every model request while the run is live, main loop and subagents alike, counted once the
  // response is whole. A falsifier still reading after the main turn ended is the run's too, so a
  // waiting run keeps counting. The stream passes through untouched.
  on('turn.step', async function* ($, e, next) {
    const mine = run && !run.ended ? run : undefined
    const result = yield* next(e)
    if (mine && !mine.ended && result.usage) {
      try {
        mine.usage = addUsage(mine.usage, result.usage)
        if (e.agentId !== undefined && mine.falsifierIds.has(e.agentId)) {
          mine.falsifierUsage = addUsage(mine.falsifierUsage, result.usage)
        }
        await draw($)
      } catch {
        // the count is the line's, never the request's
      }
    }
    return result
  }).catch(async function* ($, e, next) {
    return yield* next(e)
  })

  // The engine's own measurement, pushed after each main-thread turn and whenever a window moves a
  // whole point.
  on('session.measure', async ($, e, next) => {
    if (run && !run.ended) {
      measured(run, e.rateLimits)
      await draw($)
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  // A run can span turns: the skill stops to ask (two stacks, say), or the main loop ends its turn
  // while background falsifiers read and is woken by their notifications. So a turn that answers
  // before the gate has passed pauses the run rather than ending it, and the next main-loop turn
  // resumes it; the time between is the person's or the notification's, not generation's.
  on('turn.start', async ($, e, next) => {
    if (run && !run.ended && run.waitingSince !== undefined) {
      run.paused += (await $.clock.now()) - run.waitingSince
      run.waitingSince = undefined
      tick($, run)
      await draw($)
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  // Its length feeds the next run's ETA only when the gate passed and the turn answered, so a run
  // that stopped early never shortens the bar.
  on('turn.complete', async ($, e, next) => {
    if (run && !run.ended && e.agentId === undefined) {
      const mine = run
      mine.timer?.cancel()
      const now = await $.clock.now()
      if (e.reason === 'answer' && !mine.sawGate) {
        mine.waitingSince = now
      } else {
        mine.endedAt = now
        mine.ended = e.reason === 'answer' ? 'done' : e.isAborted ? 'interrupted' : 'stopped'
      }
      await recount($)
      if (mine.ended) {
        measured(mine, await readLimits($))
        $.ui.log(spent(mine.usage, mine.falsifierUsage, mine.firstLimits, mine.lastLimits))
      }
      await draw($)
      if (mine.ended === 'done' && mine.repo) {
        const key = historyKey(mine.repo, mine.kind)
        const past = await $.store.get(key)
        const kept = Array.isArray(past) ? past.filter(n => typeof n === 'number') : []
        await $.store.set(key, [...kept, elapsedMs(mine, now) / 1000].slice(-KEEP))
      }
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  on('session.end', async ($, e, next) => {
    run?.timer?.cancel()
    run = undefined
    $.ui.status(undefined)
    return next(e)
  }).catch(($, e, next) => next(e))
}
