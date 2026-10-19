import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import {
  NO_USAGE,
  addUsage,
  assignedW,
  bar,
  checkpoints,
  clock,
  label,
  line,
  median,
  moved,
  outputPage,
  pagePath,
  parseActivity,
  repoKey,
  runKind,
  runsGate,
  spent,
  summary,
  tokens,
} from './board'

// Rows of hooks/activity.json, in its order. A test runs with no file system, so it cannot read the
// shipped table; skills/review-map/tests/activity.rb is what holds that file to both readers.
const ACTIVITY = `[
  ["claim-falsifier", "🥊 falsifiers reading"],
  ["coverage-gate\\\\.sh", "🚪 coverage gate"],
  ["excerpt\\\\.sh", "✂️  cutting excerpts"],
  ["page-skeleton\\\\.sh", "🏗️  laying out the page"],
  ["^(Write|Edit) .*\\\\.html|>\\\\s*\\\\S+\\\\.html", "✍️  writing the page"],
  ["\\\\b(rg|grep|Grep)\\\\b", "🔎 tracing consumers"],
  ["\\\\b(sed|cat|head|Read)\\\\b", "👀 reading code"]
]`

const API = { input_tokens: 10, output_tokens: 1_000, cache_read_input_tokens: 600_000, cache_creation_input_tokens: 30_000 }
const FIVE = (percentUsed: number) => ({ kind: 'five_hour', percentUsed, resetsAt: '2026-10-19T20:00:00Z' })

const TMPDIR = '/var/folders/xy/T/'
const PAGE = '/var/folders/xy/T/review-map/app-pr-7/page.html'
const STAGED = `<!-- <section class="cp"> a comment describing a checkpoint </section> -->
<section class="cp" id="cp-a"><h3>Does nil reach the client?</h3></section>
<section class="cp" id="cp-b"><h3>Is the index used? <span class="pending">pending</span></h3></section>`

describe('board', () => {
  test('the summary is the one progress.rb builds, so one table matches both', () => {
    expect(summary({ tool: 'Agent', subagent_type: 'accountable-review:claim-falsifier' }))
      .toBe('Agent accountable-review:claim-falsifier   ')
    expect(summary({ tool: 'Bash', command: 'rg -n foo' })).toBe('Bash  rg -n foo  ')
  })

  test('first match wins, and reading the page is not writing it', () => {
    const table = parseActivity(ACTIVITY)
    expect(label(table, 'Bash  scripts/excerpt.sh --at x  ')).toBe('✂️  cutting excerpts')
    expect(label(table, `Edit   ${PAGE} `)).toBe('✍️  writing the page')
    expect(label(table, `Read   ${PAGE} `)).toBe('👀 reading code')
    expect(label(table, `Bash  rg -n 'id="cp-' ${PAGE}  `)).toBe('🔎 tracing consumers')
    expect(label(table, 'Bash  ls  ')).toBeUndefined()
  })

  test('the page is read off the command SKILL.md gives, $W and all', () => {
    const vars = { TMPDIR, W: assignedW('W="${TMPDIR:-/tmp}/review-map/app-pr-7"; mkdir -p "$W"', { TMPDIR }) }
    expect(vars.W).toBe('/var/folders/xy/T/review-map/app-pr-7')
    expect(pagePath({ command: 'scripts/page-skeleton.sh --out "$W/page.html" --title "x"' }, vars)).toBe(PAGE)
    expect(pagePath({ command: `scripts/page-skeleton.sh --out "${PAGE}"` })).toBe(PAGE)
    expect(pagePath({ command: 'page-skeleton.sh --out "$W/page.html"' })).toBeUndefined() // W never assigned
    expect(assignedW('W="${TMPDIR:-/tmp}/review-map/x"', {})).toBe('/tmp/review-map/x')
    expect(pagePath({ file_path: PAGE })).toBe(PAGE)
    expect(pagePath({ file_path: '/repo/app/models/user.rb' })).toBeUndefined()
    expect(outputPage('/review-map 7 --output /tmp/out/ --effort low')).toBe('/tmp/out/index.html')
    expect(outputPage('/review-map 7')).toBeUndefined()
  })

  test('the gate is run, not read', () => {
    expect(runsGate({ tool: 'Bash', command: '/plug/skills/review-map/scripts/coverage-gate.sh p.html B H' })).toBe(true)
    expect(runsGate({ tool: 'Bash', command: 'cd /x && sh scripts/coverage-gate.sh p.html B H' })).toBe(true)
    expect(runsGate({ tool: 'Bash', command: 'cat scripts/coverage-gate.sh' })).toBe(false)
    expect(runsGate({ tool: 'Bash', command: 'rg -n coverage-gate.sh SKILL.md' })).toBe(false)
    expect(runsGate({ tool: 'Read', file_path: '/plug/scripts/coverage-gate.sh' })).toBe(false)
  })

  test('each kind of run is its own history', () => {
    expect(runKind('/review-map 7')).toBe('high')
    expect(runKind('/review-map 7 --effort low')).toBe('low')
    expect(runKind('/review-map 7 --update')).toBe('update')
    expect(runKind('/review-map feature/--update-thing')).toBe('high')
  })

  test('a credential in the remote never reaches the store key', () => {
    expect(repoKey('https://jdoe:ghp_secret@github.com/acme/app.git', '/r')).toBe('https://github.com/acme/app.git')
    expect(repoKey('git@github.com:acme/app.git', '/r')).toBe('git@github.com:acme/app.git')
    expect(repoKey(null, '/repo')).toBe('/repo')
  })

  test('checkpoints are counted on the page, comments stripped', () => {
    expect(checkpoints(STAGED)).toBe('📄 1/2')
    expect(checkpoints('<html><body></body></html>')).toBe('📄 page started')
  })

  test('with nothing recorded there is no bar, only the clock', () => {
    const s = line({ tick: 0, elapsed: 820, tools: 3, falsifiers: 0 })
    expect(s).toContain('13:40')
    expect(s).not.toContain('~')
    expect(s).not.toContain('▕')
  })

  test('the bar is labelled an estimate and never reaches 100% before the end', () => {
    const running = line({ tick: 0, elapsed: 3000, eta: 1410, tools: 1, falsifiers: 0 })
    expect(running).toContain(' 99%')
    expect(running).toContain('~23:30')
    expect(line({ tick: 0, elapsed: 1378, eta: 1410, ended: 'done', tools: 1, falsifiers: 0 })).toContain('100%')
    expect(median([30, 10, 20])).toBe(20)
    expect(median([])).toBeUndefined()
    expect(clock(1410)).toBe('23:30')
    expect(bar(0.5)).toBe(`▕${'█'.repeat(10)}${' '.repeat(10)}▏`)
  })

  test('tokens are the four counts summed, and a window that reset has no share', () => {
    const u = addUsage(addUsage(NO_USAGE, API), API)
    expect(u).toEqual({ input: 20, output: 2_000, cacheRead: 1_200_000, cacheWrite: 60_000 })
    expect(addUsage(u, null)).toEqual(u)
    expect(tokens(1_262_020)).toBe('1.26M')
    expect(tokens(48_400)).toBe('48k')
    expect(tokens(12_400_000)).toBe('12.4M')
    expect(moved(FIVE(30), FIVE(38.5))).toBe(8.5)
    expect(moved(FIVE(30), { ...FIVE(4), resetsAt: '2026-10-19T23:00:00Z' })).toBeUndefined()
    expect(moved(undefined, FIVE(4))).toBeUndefined()
    expect(line({ tick: 0, elapsed: 1, tools: 1, falsifiers: 0, tokens: 1_262_020, window: 8.5 }))
      .toContain('🪙 1.26M  ⏳ 5h +8.5%')
    expect(line({ tick: 0, elapsed: 1, tools: 1, falsifiers: 0, tokens: 0 })).not.toContain('🪙')
  })

  test('the closing line says what was read, and names a reset rather than a share', () => {
    const u = addUsage(NO_USAGE, API)
    const said = spent(u, u, [FIVE(30), { kind: 'seven_day', percentUsed: 12 }],
      [FIVE(36), { kind: 'seven_day', percentUsed: 13 }])
    expect(said).toContain('review map used 631k tokens')
    expect(said).toContain('falsifiers 631k of it')
    expect(said).toContain('5-hour window 30% → 36% (+6%)')
    expect(said).toContain('7-day window 12% → 13% (+1%)')
    expect(spent(u, NO_USAGE, [FIVE(30)], [{ ...FIVE(2), resetsAt: 'later' }])).toContain('5-hour window at 2%')
    expect(spent(u, NO_USAGE, [], [])).not.toContain('window')
    expect(spent(u, NO_USAGE, [], [])).not.toContain('falsifiers')
  })
})

// The world beneath the plugin: the shipped table and a staged page on disk, one repository, a
// TMPDIR, and every status the line sets. A Bash command containing FAIL exits non-zero.
function world(on: On, files: Record<string, string>, limits: { now: unknown[] } = { now: [] }) {
  const statuses: (string | undefined)[] = []
  const logs: string[] = []
  on('ui.log', (_$, e) => {
    logs.push((e as { text: string }).text)
    return { value: undefined } as never
  })
  on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200_000 }, rateLimits: limits.now } }) as never)
  on('turn.step', async function* (_$, e) {
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn',
      usage: { ...API, model: 'm' } } as never
  })
  on('fs.read', (_$, e) => {
    if (e.path.endsWith('/hooks/activity.json')) return { value: ACTIVITY }
    const text = files[e.path]
    if (text === undefined) return { deny: `ENOENT ${e.path}` }
    return { value: text }
  })
  on('env.get', (_$, e) => ({ value: (e as { name: string }).name === 'TMPDIR' ? TMPDIR : undefined }) as never)
  on('session.repo', () => ({ value: { root: '/repo', remote: 'git@github.com:acme/app.git', internal: false } }) as never)
  on('ui.status', (_$, e) => {
    statuses.push(e.text)
    return { value: undefined } as never
  })
  on('tool.call', (_$, e) => {
    const failed = String((e as { command?: unknown }).command ?? '').includes('FAIL')
    return { result: '', text: failed ? 'exit 1' : 'ok', isError: failed } as never
  })
  on('agent.spawn', () => ({ model: 'opus', agentId: 'a1' }) as never)
  on('turn.start', (_$, e) => ({ turnId: e.turnId }) as never)
  on('turn.complete', () => ({ text: '' }))
  on('prompt.submit', (_$, e) => e as never)
  on('session.measure', () => ({ changed: [] }) as never)
  return Object.assign(statuses, { logs })
}

// One model request, read to its end as the engine reads it.
async function step($: { turn: { step: (e: never) => AsyncGenerator<unknown, unknown> & { result: Promise<unknown> } } }, agentId?: string) {
  const s = $.turn.step({ turnId: 't', index: 0, model: 'm', messageCount: 1, agentId } as never)
  for await (const _ of s) { /* no chunks */ }
  return s.result
}

const bash = (command: string, extra: Record<string, unknown> = {}) =>
  ({ tool: 'Bash', tool_use_id: `t-${command.length}`, command, ...extra }) as never

const finish = (reason: 'answer' | 'aborted') =>
  ({ answer: '', durationMs: 1, isAborted: reason === 'aborted', turnId: 't', reason }) as never

const GATE = '/plug/skills/review-map/scripts/coverage-gate.sh page.html BASE HEAD'

describe('progress line', () => {
  test('another skill draws nothing', async ($, on) => {
    mock.clock(on)
    mock.store(on)
    const statuses = world(on, {})
    await $.prompt.submit({ text: '/commit' } as never)
    await $.prompt.submit({ text: 'what does review-map do?' } as never)
    await $.tool.call({ tool: 'Skill', tool_use_id: 's0', skill: 'commit' } as never)
    await $.tool.call(bash('rg -n foo'))
    expect(statuses).toEqual([])
  })

  test('activity, counts and checkpoints are read from the run', async ($, on) => {
    const time = mock.clock(on)
    mock.store(on)
    const files: Record<string, string> = {}
    const statuses = world(on, files)
    await $.prompt.submit({ text: '/accountable-review:review-map 7' } as never)
    await $.tool.call(bash('W="${TMPDIR:-/tmp}/review-map/app-pr-7"; mkdir -p "$W"'))
    await $.tool.call(bash('rg -n current_user app/'))
    expect(statuses.at(-1)).toContain('🔎 tracing consumers')

    // A falsifier's own reads are its work, not the run's: not counted, no activity change.
    await $.tool.call(bash('scripts/excerpt.sh --at x', { agentId: 'f1' }))
    expect(statuses.at(-1)).toContain('🔧 2')
    expect(statuses.at(-1)).not.toContain('excerpts')

    await $.agent.spawn({ subagentType: 'accountable-review:claim-falsifier' } as never)
    expect(statuses.at(-1)).toContain('🥊 1')

    // SKILL.md's own command, verbatim.
    files[PAGE] = STAGED
    await $.tool.call(bash('W="${TMPDIR:-/tmp}/review-map/app-pr-7"; scripts/page-skeleton.sh --out "$W/page.html" --title "x"'))
    expect(statuses.at(-1)).toContain('📄 1/2')

    await time.advance(61_000)
    expect(statuses.at(-1)).toContain('1:01')
  })

  test('tokens and the 5-hour window are counted for the run, falsifiers included', async ($, on) => {
    const time = mock.clock(on)
    mock.store(on)
    const limits = { now: [] as unknown[] } // a fresh session: no reading before the first response
    const statuses = world(on, {}, limits)

    await step($ as never) // before the run: not its tokens
    await $.prompt.submit({ text: '/review-map 7' } as never)
    expect(statuses.at(-1)).not.toContain('🪙')

    await step($ as never)
    expect(statuses.at(-1)).toContain('🪙 631k')
    expect(statuses.at(-1)).not.toContain('⏳')

    await $.session.measure({ context: { window: 200_000 }, rateLimits: [FIVE(30)] } as never)
    const spawned = await $.agent.spawn({ subagentType: 'accountable-review:claim-falsifier' } as never)
    await step($ as never, (spawned as { agentId: string }).agentId)
    await step($ as never, 'some-other-agent')
    expect(statuses.at(-1)).toContain('🪙 1.89M')

    await $.session.measure({ context: { window: 200_000 }, rateLimits: [FIVE(34.5)] } as never)
    expect(statuses.at(-1)).toContain('⏳ 5h +4.5%')

    limits.now = [FIVE(36)]
    await $.tool.call(bash(GATE))
    await time.advance(1_000)
    await $.turn.complete(finish('answer'))
    expect(statuses.at(-1)).toContain('⏳ 5h +6%')
    expect(statuses.logs).toEqual([
      'review map used 1.89M tokens (30 input · 90k cache write · 1.80M cache read · 3k output; ' +
        'falsifiers 631k of it) — 5-hour window 30% → 36% (+6%), account-wide',
    ])

    await step($ as never) // after the run: not its tokens
    expect(statuses.at(-1)).toContain('🪙 1.89M')
  })

  test('an --output run reads its page where the command put it', async ($, on) => {
    mock.clock(on)
    mock.store(on)
    const files: Record<string, string> = { '/tmp/out/index.html': STAGED }
    const statuses = world(on, files)
    await $.prompt.submit({ text: '/review-map 7 --output /tmp/out' } as never)
    await $.tool.call({ tool: 'Edit', tool_use_id: 'e1', file_path: '/tmp/out/index.html' } as never)
    expect(statuses.at(-1)).toContain('📄 1/2')
  })

  test('a run that spans turns pauses between them and finishes on the gate', async ($, on) => {
    const time = mock.clock(on)
    const store: Record<string, unknown> = {}
    mock.store(on, store)
    const statuses = world(on, {})

    await $.prompt.submit({ text: '/review-map 7' } as never)
    await time.advance(60_000)
    await $.turn.complete(finish('answer')) // asks which stack: not finished, not stopped
    expect(statuses.at(-1)).toContain('⏸ review map')
    expect(statuses.at(-1)).toContain('1:00')

    await time.advance(300_000) // the person thinks about it
    expect(statuses.at(-1)).toContain('1:00')

    await $.prompt.submit({ text: 'the Rails one' } as never)
    await $.turn.start({ text: 'the Rails one', turnId: 't2' } as never)
    expect(statuses.at(-1)).toContain('🤔 thinking')

    // Reading the gate, or running it and failing, is not passing it.
    await $.tool.call(bash('cat scripts/coverage-gate.sh'))
    await $.tool.call(bash(`${GATE} # FAIL`))
    await time.advance(60_000)
    await $.turn.complete(finish('answer'))
    expect(statuses.at(-1)).toContain('waiting for the next turn')

    await $.turn.start({ text: '', turnId: 't3' } as never)
    await $.tool.call(bash(GATE))
    await time.advance(60_000)
    await $.turn.complete(finish('answer'))
    expect(statuses.at(-1)).toMatch(/^✅ review map .* done/)
    expect(statuses.at(-1)).toContain('3:00') // generation only, the wait taken out
  })

  test('an interrupt ends the run and records nothing', async ($, on) => {
    const time = mock.clock(on)
    mock.store(on)
    const statuses = world(on, {})
    await $.prompt.submit({ text: '/review-map 7' } as never)
    await $.tool.call(bash(GATE))
    await time.advance(60_000)
    await $.turn.complete(finish('aborted'))
    expect(statuses.at(-1)).toMatch(/^⏹ review map .* interrupted/)

    await $.prompt.submit({ text: 'something else' } as never)
    expect(statuses.at(-1)).toBeUndefined()
    await $.prompt.submit({ text: '/review-map 8' } as never)
    expect(statuses.at(-1)).not.toContain('~')
  })

  test('a finished run feeds the next bar of its own kind only', async ($, on) => {
    const time = mock.clock(on)
    mock.store(on)
    const statuses = world(on, {})

    await $.prompt.submit({ text: '/accountable-review:review-map 7 --update' } as never)
    expect(statuses.at(-1)).not.toContain('~')
    await $.tool.call(bash(GATE))
    await time.advance(180_000)
    await $.turn.complete(finish('answer'))
    expect(statuses.at(-1)).toMatch(/^✅ review map .* done/)

    await $.prompt.submit({ text: '/review-map 9' } as never) // a full run: no update history counts
    expect(statuses.at(-1)).not.toContain('~')
    await $.tool.call(bash(GATE))
    await time.advance(1_410_000)
    await $.turn.complete(finish('answer'))

    await $.prompt.submit({ text: 'next PR' } as never)
    await $.tool.call({ tool: 'Skill', tool_use_id: 's1', skill: 'accountable-review:review-map', args: '12' } as never)
    expect(statuses.at(-1)).toContain('~23:30')
  })
})
