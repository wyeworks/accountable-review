import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { bar, checkpoints, clock, label, line, median, pagePath, parseActivity, repoKey, summary } from './board'

// Rows of hooks/activity.json, in its order. A test runs with no file system, so it cannot read the
// shipped table; skills/review-map/tests/activity.rb is what holds that file to both readers.
const ACTIVITY = `[
  ["claim-falsifier", "🥊 falsifiers reading"],
  ["coverage-gate\\\\.sh", "🚪 coverage gate"],
  ["excerpt\\\\.sh", "✂️  cutting excerpts"],
  ["page-skeleton\\\\.sh", "🏗️  laying out the page"],
  ["page/index\\\\.html|page\\\\.html|body\\\\.html|\\\\bWrite\\\\b.*\\\\.html|\\\\bEdit\\\\b.*\\\\.html", "✍️  writing the page"],
  ["\\\\b(rg|grep|Grep)\\\\b", "🔎 tracing consumers"]
]`

const PAGE = '/tmp/review-map/app-pr-7/page.html'
const STAGED = `<!-- <section class="cp"> a comment describing a checkpoint </section> -->
<section class="cp" id="cp-a"><h3>Does nil reach the client?</h3></section>
<section class="cp" id="cp-b"><h3>Is the index used? <span class="pending">pending</span></h3></section>`

describe('board', () => {
  test('the summary is the one progress.rb builds, so one table matches both', () => {
    expect(summary({ tool: 'Agent', subagent_type: 'accountable-review:claim-falsifier' }))
      .toBe('Agent accountable-review:claim-falsifier   ')
    expect(summary({ tool: 'Bash', command: 'rg -n foo' })).toBe('Bash  rg -n foo  ')
  })

  test('first match wins and no match is no label', () => {
    const table = parseActivity(ACTIVITY)
    expect(label(table, 'Bash  scripts/excerpt.sh --at x  ')).toBe('✂️  cutting excerpts')
    expect(label(table, `Edit   ${PAGE} `)).toBe('✍️  writing the page')
    expect(label(table, 'Bash  ls  ')).toBeUndefined()
  })

  test('the page is named by the skeleton command or by an edit of the derived page', () => {
    expect(pagePath({ command: `scripts/page-skeleton.sh --out "${PAGE}" --title "x"` })).toBe(PAGE)
    expect(pagePath({ command: 'page-skeleton.sh --out "$W/page.html"' })).toBeUndefined()
    expect(pagePath({ file_path: PAGE })).toBe(PAGE)
    expect(pagePath({ file_path: '/repo/app/models/user.rb' })).toBeUndefined()
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

// The world beneath the plugin: the shipped table and a staged page on disk, one repository, and
// every status the line sets.
function world(on: On, files: Record<string, string>) {
  const statuses: (string | undefined)[] = []
  on('fs.read', (_$, e) => {
    if (e.path.endsWith('/hooks/activity.json')) return { value: ACTIVITY }
    const text = files[e.path]
    if (text === undefined) return { deny: `ENOENT ${e.path}` }
    return { value: text }
  })
  on('session.repo', () => ({ value: { root: '/repo', remote: 'git@github.com:acme/app.git', internal: false } }) as never)
  on('ui.status', (_$, e) => {
    statuses.push(e.text)
    return { value: undefined } as never
  })
  on('tool.call', () => ({ result: '', text: 'ok' }) as never)
  on('agent.spawn', () => ({ model: 'opus', agentId: 'a1' }) as never)
  on('turn.complete', () => ({ text: '' }))
  on('prompt.submit', (_$, e) => e as never)
  return statuses
}

const bash = (command: string, extra: Record<string, unknown> = {}) =>
  ({ tool: 'Bash', tool_use_id: `t-${command.length}`, command, ...extra }) as never

const finish = (reason: 'answer' | 'aborted') =>
  ({ answer: '', durationMs: 1, isAborted: reason === 'aborted', turnId: 't', reason }) as never

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
    await $.tool.call(bash('rg -n current_user app/'))
    expect(statuses.at(-1)).toContain('🔎 tracing consumers')

    // A falsifier's own reads are its work, not the run's: not counted, no activity change.
    await $.tool.call(bash('scripts/excerpt.sh --at x', { agentId: 'f1' }))
    expect(statuses.at(-1)).toContain('🔧 1')
    expect(statuses.at(-1)).not.toContain('excerpts')

    await $.agent.spawn({ subagentType: 'accountable-review:claim-falsifier' } as never)
    expect(statuses.at(-1)).toContain('🥊 1')

    files[PAGE] = STAGED
    await $.tool.call(bash(`scripts/page-skeleton.sh --out "${PAGE}" --title "x"`))
    expect(statuses.at(-1)).toContain('📄 1/2')

    await time.advance(61_000)
    expect(statuses.at(-1)).toContain('1:01')
  })

  test('a finished run with the gate feeds the next bar; a stopped one does not', async ($, on) => {
    const time = mock.clock(on)
    mock.store(on)
    const statuses = world(on, {})

    await $.prompt.submit({ text: '/review-map' } as never)
    await time.advance(300_000)
    await $.turn.complete(finish('answer')) // no gate seen: stopped, not recorded
    expect(statuses.at(-1)).toContain('⏹ stopped')

    await $.prompt.submit({ text: 'again' } as never)
    expect(statuses.at(-1)).toBeUndefined()

    await $.prompt.submit({ text: '/accountable-review:review-map --effort low' } as never)
    expect(statuses.at(-1)).not.toContain('~')
    await $.tool.call(bash('scripts/coverage-gate.sh page.html BASE HEAD'))
    await time.advance(1_410_000)
    await $.turn.complete(finish('answer'))
    expect(statuses.at(-1)).toContain('✅ done')

    await $.prompt.submit({ text: 'next PR' } as never)
    await $.tool.call({ tool: 'Skill', tool_use_id: 's1', skill: 'accountable-review:review-map' } as never)
    expect(statuses.at(-1)).toContain('~23:30')
  })
})
