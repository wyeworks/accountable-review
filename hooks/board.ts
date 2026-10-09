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

// Which kind of run the command asked for. An --update re-run reads only the delta and a low-effort
// run sends no falsifiers, so each finishes on its own clock and keeps its own history: a median
// over all three would set a full run's bar by a three-minute update.
export type RunKind = 'update' | 'low' | 'high'

export function runKind(command: string): RunKind {
  if (/(^|\s)--update(?=\s|$)/.test(command)) return 'update'
  if (/(^|\s)--effort[= ]low(?=\s|$)/.test(command)) return 'low'
  return 'high'
}

// Where --output puts the page: <dir>/index.html, named in the command and nowhere else.
export function outputPage(command: string): string | undefined {
  const m = command.match(/(?:^|\s)--output[= ]+("([^"]+)"|'([^']+)'|(\S+))/)
  const dir = m && (m[2] ?? m[3] ?? m[4])
  return dir ? `${dir.replace(/\/+$/, '')}/index.html` : undefined
}

// The shell variables SKILL.md writes the page path with. Step 1 derives
// W="${TMPDIR:-/tmp}/review-map/<repo>-pr-<N>" and step 9 runs `page-skeleton.sh --out
// "$W/page.html"`, so the path is read by expanding what the run itself assigned. Whatever is
// still a variable after that is unknown, and an unknown path is no path.
export type Vars = { W?: string; TMPDIR?: string }

export function expand(text: string, vars: Vars): string | undefined {
  const out = text
    .replace(/\$\{TMPDIR:-([^}]*)\}/g, (_, fallback: string) => vars.TMPDIR || fallback)
    .replace(/\$\{?(W|TMPDIR)\}?(?![A-Za-z0-9_])/g, (whole, name: 'W' | 'TMPDIR') => vars[name] ?? whole)
    .replace(/\/{2,}/g, '/')
  return out.includes('$') ? undefined : out
}

// The W a Bash command assigns, expanded, or undefined when it assigns none.
export function assignedW(command: string, vars: Vars): string | undefined {
  const m = command.match(/(?:^|[\s;&|])W=("([^"]*)"|'([^']*)'|(\S+))/)
  const raw = m && (m[2] ?? m[3] ?? m[4])
  return raw === null || raw === undefined ? undefined : expand(raw, vars)
}

// The page a run is staging: `page-skeleton.sh --out <path>` names it first, and an Edit or a
// Write of the derived page names it again.
export function pagePath(e: Record<string, unknown>, vars: Vars = {}): string | undefined {
  if (typeof e.command === 'string') {
    const m = e.command.match(/page-skeleton\.sh\b.*?--out[= ]+("([^"]+)"|'([^']+)'|(\S+))/)
    const path = m && (m[2] ?? m[3] ?? m[4])
    if (path) return expand(path, vars)
  }
  if (typeof e.file_path === 'string' && /\/review-map\/[^/]+\/page\.html$/.test(e.file_path)) {
    return e.file_path
  }
  return undefined
}

// The coverage gate run, as distinct from read: the script is the command word — first, after a
// separator, or handed to a shell — rather than the argument of cat, sed or grep.
export function runsGate(e: Record<string, unknown>): boolean {
  return (
    e.tool === 'Bash' &&
    typeof e.command === 'string' &&
    /(^|[;&|(]\s*|\b(?:ba)?sh\s+)[^\s;&|]*coverage-gate\.sh(?=\s|$)/m.test(e.command)
  )
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
  elapsed: number // seconds of generation: frozen once the run ends, paused while it waits
  eta?: number // the median of this repository's earlier generations; absent with none recorded
  ended?: 'done' | 'stopped' | 'interrupted'
  waiting?: boolean // the turn ended with the run unfinished; the next turn resumes it
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
    r.ended === 'done' ? '✅' : r.ended ? '⏹' : r.waiting ? '⏸' : MOON[r.tick % MOON.length]
  // The icon carries the state's glyph, so the words beside it carry none.
  const status = r.ended ?? (r.waiting ? 'waiting for the next turn' : (r.activity ?? '🤔 thinking'))
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
