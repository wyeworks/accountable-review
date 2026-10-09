// board.ts — the pure half of the progress line: what a field says, given what was read. Nothing
// here reads anything; progress.ts does the reading, and this file turns readings into one line.
// The rule both keep is progress.rb's: every field is READ, never guessed.

export type Activity = readonly (readonly [RegExp, string])[]

export const MOON = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'] as const
const BLOCKS = ['▏', '▎', '▍', '▌', '▋', '▊', '▉'] as const

// hooks/activity.json is the one copy of the table, read by this mod and by progress.rb alike.
export function parseActivity(json: string): Activity {
  const rows = JSON.parse(json) as [string, string][]
  return rows.map(([pattern, label]) => [new RegExp(pattern), label] as const)
}

// The same summary progress.rb#calls builds from a transcript's tool_use block, so the one table
// matches the same text in both. A tool call's arguments arrive flat on the event.
export function summary(e: Record<string, unknown>): string {
  const s = (k: string) => (typeof e[k] === 'string' ? (e[k] as string) : '')
  return `${s('tool')} ${s('subagent_type')} ${s('command')} ${s('file_path')} ${s('pattern')}`
}

// First match wins, so specific beats general; no match leaves the previous activity standing.
export function label(table: Activity, text: string): string | undefined {
  return table.find(([re]) => re.test(text))?.[1]
}

// The page a run is staging: `page-skeleton.sh --out <path>` names it first, and an Edit or a
// Write of the derived page names it again. Interactive runs write $W/page.html; --output runs
// write <dir>/index.html, which only the skeleton command names.
export function pagePath(e: Record<string, unknown>): string | undefined {
  if (typeof e.command === 'string') {
    const m = e.command.match(/page-skeleton\.sh\b.*?--out[= ]+("([^"]+)"|'([^']+)'|(\S+))/)
    const path = m && (m[2] ?? m[3] ?? m[4])
    if (path && !path.includes('$')) return path
  }
  if (typeof e.file_path === 'string' && /\/review-map\/[^/]+\/page\.html$/.test(e.file_path)) {
    return e.file_path
  }
  return undefined
}

// A pending checkpoint is a <section class="cp"> whose <h3> carries span.pending, so each
// checkpoint is read up to its own close. Comments are stripped first: the template's own
// comments describe these sections in the same words.
export function checkpoints(html: string): string {
  const bare = html.replace(/<!--[\s\S]*?-->/g, '')
  const cps = bare.match(/<section class="cp\b[\s\S]*?<\/section>/g) ?? []
  const written = cps.filter(c => !c.includes('class="pending"')).length
  return cps.length === 0 ? '📄 page started' : `📄 ${written}/${cps.length}`
}

// What a repository's generation times are kept under: its remote, so every clone and worktree of
// one repository shares a history, with any credential an HTTPS remote carries taken out first —
// the store is a file on disk. A repository with no remote is keyed by its root.
export function repoKey(remote: string | null, root: string): string {
  if (!remote) return root
  return remote.replace(/^([a-z][a-z0-9+.-]*:\/\/)[^/@]*@/i, '$1')
}

export function median(secs: readonly number[]): number | undefined {
  if (secs.length === 0) return undefined
  const sorted = [...secs].sort((a, b) => a - b)
  return sorted[Math.floor(sorted.length / 2)]
}

export function clock(secs: number): string {
  const s = Math.max(0, Math.floor(secs))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}

export function bar(frac: number, cells = 20): string {
  const full = Math.floor(frac * cells)
  const part = Math.floor((frac * cells - full) * BLOCKS.length)
  let s = '█'.repeat(full)
  if (full < cells && part > 0) s += BLOCKS[part]
  return `▕${s.padEnd(cells)}▏`
}

export type Reading = {
  tick: number
  elapsed: number // seconds of generation, frozen once the turn ends
  eta?: number // the median of this repository's earlier generations; absent with none recorded
  ended?: 'done' | 'stopped' | 'interrupted'
  activity?: string
  tools: number
  falsifiers: number
  checkpoints?: string
}

// The bar is the only estimate on the line and it is labelled as one (~), held below 100% until
// the run ends. With no earlier generation recorded there is no bar at all: the eval harness can
// fall back to a documented order of magnitude, but here that would be progress invented.
export function line(r: Reading): string {
  const icon =
    r.ended === 'done' ? '✅' : r.ended ? '⏹' : MOON[r.tick % MOON.length]
  const status =
    r.ended === 'done'
      ? '✅ done'
      : r.ended === 'interrupted'
        ? '⏹ interrupted'
        : r.ended === 'stopped'
          ? '⏹ stopped'
          : (r.activity ?? '🤔 thinking')
  const bits = [`${icon} review map`]
  if (r.eta !== undefined && r.eta > 0) {
    const frac = r.ended === 'done' ? 1 : Math.min(r.elapsed / r.eta, 0.99)
    bits.push(bar(frac), `${String(Math.floor(frac * 100)).padStart(3)}%`,
      `${clock(r.elapsed)} / ~${clock(r.eta)}`)
  } else {
    bits.push(clock(r.elapsed))
  }
  bits.push(status)
  if (r.tools > 0) bits.push(`🔧 ${r.tools}`)
  if (r.falsifiers > 0) bits.push(`🥊 ${r.falsifiers}`)
  if (r.checkpoints) bits.push(r.checkpoints)
  return bits.join('  ')
}
