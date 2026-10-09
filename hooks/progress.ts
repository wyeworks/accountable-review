// progress.ts — the e2e progress board (skills/review-map/evals/e2e/progress.rb), as one status
// line in Claude Code while /accountable-review:review-map runs interactively.
//
//   🌔 review map  ▕███████████▍       ▏  47%  11:02 / ~23:30  🔎 tracing consumers  🔧 38  🥊 4  📄 2/4
//
// Every field is READ, never guessed, and that is the rule this file keeps: a progress line that
// invents progress is the verification badge of the terminal, and the page itself is forbidden
// that badge. Three sources, each one the engine or the run already produces:
//
//   * engine events — asking for the skill starts the run, each main-loop tool call names the
//     activity through hooks/activity.json (the table progress.rb reads too), each claim-falsifier
//     spawn is counted, and the turn ending ends the run;
//   * the page the run is staging — checkpoints written against pending ones;
//   * the clock, against the median of this repository's earlier generations, which this file
//     records itself. With none recorded there is no bar, only elapsed time.
//
// The activity is the latest tool call by purpose, never a step number: steps interleave and
// cannot be read off a run (evals/README.md § Profiling one run), and this does not pretend
// otherwise. It observes and nothing else — every hook passes its event on unchanged, and every
// one has a .catch that still does, so a bug in the line can never stall a generation.

import type { EngineInterface, Register, Timer } from 'claude-code'

import { type Activity, checkpoints, label, line, median, pagePath, parseActivity, repoKey, summary } from './board'

const REVIEW_MAP = /(^|:)review-map$/
const FALSIFIER = /(^|:)claim-falsifier$/
const KEEP = 20 // generations remembered per repository

type Run = {
  started: number
  ended?: 'done' | 'stopped' | 'interrupted'
  endedAt?: number
  activity?: string
  tools: number
  falsifiers: number
  page?: string
  checkpoints?: string
  sawGate: boolean
  eta?: number
  repo?: string
  tick: number
  timer?: Timer
}

// The module's own variables start over on a reload, as register runs again.
let table: Activity = []
let run: Run | undefined

async function draw($: EngineInterface) {
  if (!run) return
  const now = run.endedAt ?? (await $.clock.now())
  $.ui.status(line({ ...run, elapsed: (now - run.started) / 1000 }))
}

async function recount($: EngineInterface) {
  if (!run?.page) return
  try {
    run.checkpoints = checkpoints(await $.fs.read(run.page))
  } catch {
    // a page mid-Edit or not written yet: the next page-touching call will have it
  }
}

function historyKey(repo: string) {
  return `generations:${repo}`
}

// The command as typed, or as the engine records a typed skill command; a sentence that merely
// mentions review-map is not a request for one.
function isCommand(text: string) {
  return /(^\s*|<command-name>)\/(accountable-review:)?review-map(?=\s|<|$)/.test(text)
}

async function start($: EngineInterface) {
  run?.timer?.cancel()
  if (table.length === 0) {
    table = parseActivity(await $.fs.read(`${$.plugin.root}/hooks/activity.json`))
  }
  const repo = await $.session.repo()
  const key = repo ? repoKey(repo.remote, repo.root) : undefined
  const past = key ? await $.store.get(historyKey(key)) : undefined
  const mine: Run = {
    started: await $.clock.now(),
    tools: 0,
    falsifiers: 0,
    sawGate: false,
    tick: 0,
    repo: key,
    eta: Array.isArray(past) ? median(past.filter((n): n is number => typeof n === 'number')) : undefined,
  }
  run = mine
  mine.timer = $.clock.every(1000, () => {
    mine.tick += 1
    void draw($)
  })
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
    if (e.turnId === undefined && isCommand(e.text)) await start($)
    return next(e)
  }).catch(($, e, next) => next(e))

  // The main loop only: progress.rb reads the parent transcript, and a falsifier's own reads are
  // its work, not the run's activity. Its spawn is what gets counted, below.
  on('tool.call', async ($, e, next) => {
    if (e.agentId !== undefined) return next(e)
    const asked = e.tool === 'Skill' && REVIEW_MAP.test(String((e as { skill?: unknown }).skill ?? ''))
    if (asked && (!run || run.ended)) {
      await start($)
      return next(e)
    }
    if (!run || run.ended) return next(e)
    const text = summary(e as unknown as Record<string, unknown>)
    run.tools += 1
    run.activity = label(table, text) ?? run.activity
    if (/coverage-gate\.sh/.test(text)) run.sawGate = true
    run.page = pagePath(e as unknown as Record<string, unknown>) ?? run.page
    await draw($)
    const result = await next(e)
    if (run?.page && /page-skeleton\.sh|\.html\b/.test(text)) {
      await recount($)
      await draw($)
    }
    return result
  }).catch(($, e, next) => next(e))

  on('agent.spawn', async ($, e, next) => {
    if (run && !run.ended && FALSIFIER.test(e.subagentType)) {
      run.falsifiers += 1
      await draw($)
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  // The run is the turn the skill expanded in. Its length feeds the next run's ETA only when the
  // turn answered and the coverage gate ran, so a run that stopped early never shortens the bar.
  on('turn.complete', async ($, e, next) => {
    if (run && !run.ended && e.agentId === undefined) {
      run.timer?.cancel()
      run.endedAt = await $.clock.now()
      const done = e.reason === 'answer' && run.sawGate
      run.ended = done ? 'done' : e.isAborted ? 'interrupted' : 'stopped'
      await recount($)
      await draw($)
      if (done && run.repo) {
        const key = historyKey(run.repo)
        const past = await $.store.get(key)
        const kept = Array.isArray(past) ? past.filter(n => typeof n === 'number') : []
        await $.store.set(key, [...kept, (run.endedAt - run.started) / 1000].slice(-KEEP))
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
