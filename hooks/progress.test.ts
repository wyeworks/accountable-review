import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import {
  assignedW,
  bar,
  checkpoints,
  clock,
  label,
  line,
  median,
  outputPage,
  pagePath,
  parseActivity,
  repoKey,
  runKind,
  runsGate,
  summary,
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
})

// The world beneath the plugin: the shipped table and a staged page on disk, one repository, a
// TMPDIR, and every status the line sets. A Bash command containing FAIL exits non-zero.
function world(on: On, files: Record<string, string>) {
  const statuses: (string | undefined)[] = []
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
  return statuses
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
    expect(statuses.at(-1)).toContain('💬 waiting for the next turn')
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
    expect(statuses.at(-1)).toContain('💬 waiting')

    await $.turn.start({ text: '', turnId: 't3' } as never)
    await $.tool.call(bash(GATE))
    await time.advance(60_000)
    await $.turn.complete(finish('answer'))
    expect(statuses.at(-1)).toContain('✅ done')
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
    expect(statuses.at(-1)).toContain('⏹ interrupted')

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
    expect(statuses.at(-1)).toContain('✅ done')

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
