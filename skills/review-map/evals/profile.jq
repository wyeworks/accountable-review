# profile.jq — the measurement. Fed the whole transcript with `jq -s`.
#
# Inputs: $skill (attribution filter, "" for none), $gap (minutes that separate two runs in one
# session), $run (which run, "" for the last), $top (slowest-N length).
#
# Emits one object: envelope, buckets, stages, slowest lists, per-tool rollup, diagnostics.

def ems: (.[0:19]+"Z"|fromdateiso8601)*1000 + (if length > 20 then (.[20:23]|tonumber) else 0 end);
def s1: (.*10|round)/10;
def iso: (./1000|floor|todate|.[0:19]|gsub("T";" "));

# Bucket a tool call by what it was FOR. The trailing comment on each arm names the SKILL.md step
# it usually serves — usually, never always. These are NOT phases and this is not a timeline:
# ledger-rows.sh (step 10) first fires four minutes into a run and again at minute thirteen, and
# page-template.html (step 9) is read before rails-nextjs.md (step 5). A counter that advanced on
# first sight of a marker would report step 10 at minute four. So a bucket names a purpose, the
# request's model time is charged to the bucket of the call it ENDED IN, and the "≈ step" column
# in the report keeps its ≈. Steps 4, 6 and 8 leave no trace at all and get no row.
#
# Bucket on the FULL argument, never the truncated display copy: the scripts live at absolute
# paths well over 70 characters, so truncating first hides `coverage-gate.sh` and `.html`.
def bucket($n; $a):
  if $n == "Artifact" then "publish"                                              # 9 publish
  elif $n == "Write" or $n == "Edit" or $n == "NotebookEdit" then
    (if $a | test("\\.html($|[^a-z])") then "publish" else "generate" end)        # 9
  elif $n == "Read" or $n == "Glob" then
    (if $a | test("review-map/(references|scripts)/") then "skill-refs"           # 1,5,7,9
     else "read-code" end)
  elif $n == "Grep" then "search"                                                 # 5
  elif $n == "Bash" then
    (if   $a | test("coverage-gate\\.sh")              then "gate"                # 10
     elif $a | test("ledger-rows\\.sh|excerpt\\.sh")   then "generate"            # 9,10
     elif $a | test("review-map/(references|scripts)/") then "skill-refs"         # 1,5,7,9
     elif $a | test("gh (pr|api)|branch -r|merge-base|rev-parse|symbolic-ref|git fetch") then "target"     # 1
     elif $a | test("diff --name-status|diff --name-only|--numstat")               then "inventory"        # 3
     elif $a | test("maxdepth 1|config/application|package\\.json|Gemfile|spec_helper|rails_helper") then "discover"  # 2
     elif $a | test("grep|\\brg\\b")                    then "search"             # 5
     elif $a | test("git show|git diff|git log|\\bcat |sed -n|\\bhead |\\btail |\\bwc ") then "read-code"  # 5,8
     else "other-bash" end)
  else "other" end;

# A command's first 70 characters are often a `cd` into an absolute path and nothing else, so the
# display copy drops that prefix and shortens long paths to their last two segments. The FULL
# argument is what bucket() sees; this is only what a human reads.
def display:
  gsub("\\s+"; " ")
  | sub("^\\s*(export\\s+)?[A-Za-z_]+=\\S+\\s+"; "")
  | sub("^cd\\s+\\S+\\s+"; "")
  | gsub("/(?:[^ /]+/)+(?<a>[^ /]+/[^ /]+)"; "…/\(.a)")
  | .[0:74];

def step($b):
  { target:"1", discover:"2", inventory:"3", "skill-refs":"1,5,7,9", "read-code":"5,8",
    search:"5", generate:"9,10", publish:"9", gate:"10" }[$b] // "—";

# ---- tool_result timestamps, indexed by the tool_use id they answer ----
(reduce (.[] | select(.type == "user" and .toolUseResult)
         | { id: (.message.content[0].tool_use_id // ""), t: (.timestamp | ems) }) as $r
        ({}; if $r.id == "" then . else .[$r.id] = $r.t end)) as $res

| ([ .[] | select(.type == "system" and (.subtype // "") == "turn_duration") | .durationMs ] | first) as $turnms
| ([ .[] | select(.type == "system" and (.subtype // "") == "turn_duration") ] | length) as $nturn
| ([ .[] | select(.type == "cost-state") ] | last) as $cost
| ([ .[] | select((.type // "") | test("compact")) ] | length) as $ncompact

# ---- assistant records, filtered, folded into one object per API response ----
| [ .[] | select(.type == "assistant" and .timestamp
                 and (if $skill == "" then true else .attributionSkill == $skill end)) ] as $asst
| ([ $asst[] | select(has("requestId") | not) ] | length) as $norq
| ([ $asst[] | .message.content[]? | select(.type == "tool_use") ] | length) as $ntu_all
| ([ $asst[] | .message.content[]? | select(.type == "tool_use")
     | select($res[.id] != null) ] | length) as $npaired

| ($asst
   | group_by(.requestId // .uuid)
   | map( sort_by(.timestamp)
        | . as $g
        | ($g[0].message.usage // {}) as $u
        | ([ $g[] | .message.content[]? | select(.type == "tool_use") ] | last) as $tu
        | ([ $g[] | .message.content[]? | select(.type == "text") | .text ] | last // "") as $say
        | { t0: ($g[0].timestamp | ems), t1: ($g[-1].timestamp | ems),
            model:  ($g[0].message.model // "-"),
            effort: ($g[0].effort // "-"),
            out:    ($u.output_tokens // 0),
            think:  ($u.output_tokens_details.thinking_tokens // 0),
            cread:  ($u.cache_read_input_tokens // 0),
            cwrite: ($u.cache_creation_input_tokens // 0),
            tool: (if $tu then $tu.name else "-" end),
            arg:  (if $tu then (($tu.input.command // $tu.input.file_path // $tu.input.pattern
                                 // $tu.input.description // "") | tostring | gsub("\\s+"; " "))
                   else "" end),
            tid:  (if $tu then $tu.id else null end),
            say:  ($say | gsub("\\s+"; " ") | .[0:78]) } )
   | sort_by(.t0)
   | map(. + { tool_ms: (if .tid and $res[.tid] then ($res[.tid] - .t1) else 0 end),
               ended:   (if .tid and $res[.tid] then $res[.tid] else .t1 end),
               b:       bucket(.tool; .arg),
               disp:    (.arg | display) } )) as $all

# ---- split one session's attributed work into runs on a long gap ----
| (($gap | tonumber) * 60000) as $gapms
| ($all
   | if length == 0 then []
     else reduce .[1:][] as $r ([[ .[0] ]];
            if ($r.t0 - (.[-1] | .[-1].ended)) > $gapms
            then . + [[ $r ]] else (.[0:-1] + [ .[-1] + [ $r ] ]) end)
     end) as $runs

| ($runs | length) as $nruns
| (if $run == "" then $nruns else ($run | tonumber) end) as $pick
| (if $nruns == 0 then [] else $runs[$pick - 1] end) as $rq

# ---- per-request time decomposition ----
| ($rq
   | if length == 0 then []
     else [ range(0; length) as $i | .[$i]
            + { ttft_ms: (if $i == 0 then 0 else (.[$i].t0 - .[$i-1].ended) end) } ]
     end) as $rq
| ($rq | map(. + { stream_ms: (.t1 - .t0) })
       | map(. + { model_ms: (.stream_ms + .ttft_ms) })) as $rq

| (if ($rq | length) == 0 then 0 else (($rq | last | .ended) - $rq[0].t0) end) as $wall_ms
| ($rq | map(.model_ms)  | add // 0) as $model_ms
| ($rq | map(.stream_ms) | add // 0) as $stream_ms
| ($rq | map(.ttft_ms)   | add // 0) as $ttft_ms
| ($rq | map(.tool_ms)   | add // 0) as $tool_ms
| ($rq | map(.out) | add // 0) as $out
| ($rq | map(.think) | add // 0) as $think

# ---- publish stages: the one boundary that cannot arrive out of order ----
| ([ $rq[] | select(.b == "publish") ]) as $pubs

| { transcript: null,
    filter: (if $skill == "" then "none (--all)" else $skill end),
    runs_in_session: $nruns,
    run: $pick,
    runs: [ range(0; $nruns) as $i | $runs[$i]
            | { i: ($i + 1), start: (.[0].t0 | iso),
                wall_s: ((((.[-1].ended) - .[0].t0) / 1000) | s1),
                requests: length, out: (map(.out) | add // 0) } ],
    start: (if ($rq|length) == 0 then null else ($rq[0].t0 | iso) end),
    end:   (if ($rq|length) == 0 then null else ($rq | last | .ended | iso) end),
    model: ($rq | map(.model) | unique | join(",")),
    effort: ($rq | map(.effort) | unique | join(",")),
    requests: ($rq | length),
    tool_calls: ($rq | map(select(.tid != null)) | length),
    wall_s:   (($wall_ms / 1000) | s1),
    model_s:  (($model_ms / 1000) | s1),
    stream_s: (($stream_ms / 1000) | s1),
    ttft_s:   (($ttft_ms / 1000) | s1),
    tool_s:   (($tool_ms / 1000) | s1),
    unaccounted_s: ((($wall_ms - $model_ms - $tool_ms) / 1000) | s1),
    out_tokens: $out,
    think_tokens: $think,
    cache_read: ($rq | map(.cread) | add // 0),
    cache_write: ($rq | map(.cwrite) | add // 0),
    context_per_request: (if ($rq|length) == 0 then 0
                          else (($rq | map(.cread) | add // 0) / ($rq | length) | round) end),
    turn_duration_s: (if $nturn == 1 then (($turnms / 1000) | s1) else null end),
    session_cost_usd: ($cost.totalCostUSD // null),
    session_tool_s: (if $cost then (($cost.totalToolDuration / 1000) | s1) else null end),
    session_api_s:  (if $cost then (($cost.totalAPIDuration / 1000) | s1) else null end),

    buckets: ($rq | group_by(.b)
              | map({ b: .[0].b, step: step(.[0].b), n: length,
                      model_s: ((map(.model_ms) | add / 1000) | s1),
                      tool_s:  ((map(.tool_ms)  | add / 1000) | s1),
                      out: (map(.out) | add), think: (map(.think) | add) })
              | sort_by(-.model_s)),

    publishes: ($pubs | map(select(.tool == "Artifact")) | length),
    stages: [ range(0; ($pubs | length)) as $i | $pubs[$i]
              | { i: ($i + 1), tool: .tool,
                  kind: (if .tool == "Artifact" then "publish" else "page write" end),
                  at_s: (((.ended - $rq[0].t0) / 1000) | s1),
                  out: .out } ],

    slowest_requests: ($rq | sort_by(-.model_ms) | .[0:$top]
                       | map({ model_s: ((.model_ms / 1000) | s1),
                               stream_s: ((.stream_ms / 1000) | s1),
                               out, think, tool, b, arg: .disp })),
    slowest_tools: ($rq | map(select(.tid != null)) | sort_by(-.tool_ms) | .[0:$top]
                    | map({ tool_s: ((.tool_ms / 1000) | s1), tool, b, arg: .disp })),
    by_tool: ($rq | map(select(.tid != null)) | group_by(.tool)
              | map({ tool: .[0].tool, n: length,
                      tool_s: ((map(.tool_ms) | add / 1000) | s1),
                      model_s: ((map(.model_ms) | add / 1000) | s1) })
              | sort_by(-.model_s)),

    timeline: ($rq | map({ at_s: (((.t0 - $rq[0].t0) / 1000) | s1),
                          model_s: ((.model_ms / 1000) | s1),
                          tool_s: ((.tool_ms / 1000) | s1),
                          out, think, tool, b, arg: .disp, say })),

    # ---- diagnostics: fail loudly, never print a plausible zero ----
    diagnostics: (
      [ if ($nruns > 0 and ($pick < 1 or $pick > $nruns)) then
          { v: "FAIL", m: "asked for run \($pick), but this transcript holds \($nruns) — see --all-runs" } else empty end,
        if ($asst | length) == 0 then
          { v: "FAIL", m: (if $skill == "" then "no assistant records with timestamps — the transcript schema moved"
                           else "no records attributed to \($skill) — wrong transcript, or the skill did not run here (try --all)" end) } else empty end,
        if ($ntu_all > 0 and $npaired == 0) then
          { v: "FAIL", m: "paired 0 of \($ntu_all) tool calls — the pairing key moved off message.content[0].tool_use_id" } else empty end,
        if ($ntu_all > 0 and $npaired > 0 and (($npaired / $ntu_all) < 0.95)) then
          { v: "WARN", m: "paired \($npaired) of \($ntu_all) tool calls; the rest were interrupted, denied, or the key drifted" } else empty end,
        if $norq > 0 then
          { v: "WARN", m: "\($norq) assistant record(s) carry no requestId — token totals for those fall back to per-record and may double-count" } else empty end,
        if ($wall_ms > 0 and ((($wall_ms - $model_ms - $tool_ms) | fabs) / $wall_ms) > 0.05) then
          { v: "WARN", m: "accounting does not close: wall \(($wall_ms/1000)|s1)s vs model+tool \((($model_ms+$tool_ms)/1000)|s1)s" } else empty end,
        if ($rq | map(select(.t1 < .t0)) | length) > 0 then
          { v: "WARN", m: "\($rq | map(select(.t1 < .t0)) | length) request(s) have inverted timestamps" } else empty end,
        if $ncompact > 0 then
          { v: "WARN", m: "context was compacted in this session; cache-read totals across the boundary are not comparable" } else empty end,
        if $nruns > 1 then
          { v: "WARN", m: "\($nruns) runs in this session (split on a >\($gap)m gap); showing run \($pick) — see --all-runs" } else empty end,
        ( ($pubs | map(select(.tool == "Artifact")) | length) as $np
          | if ($np > 0 and $np < 3) then
              { v: "WARN", m: "\($np) publish event(s); SKILL.md step 9 describes three stages — the run published fewer times than the procedure asks" } else empty end ),
        # Keyed on Artifact calls, not on writes of an .html file: a section eval writes a
        # fragment and never publishes, and treating that write as a publish would fire the
        # missing-gate warning on every eval run.
        ( if ($pubs | map(select(.tool == "Artifact")) | length) == 0 then
            { v: "SKIP", m: "nothing was published in this run — a section fragment, or a run that stopped before step 9" }
          else
            ((["inventory","gate"] - ($rq | map(.b) | unique)) as $missing
             | if ($missing | length) > 0 then
                 { v: "WARN", m: "the page was published but no \($missing | join("/")) call was seen — the run skipped a step, or the bucket table is behind SKILL.md" } else empty end)
          end ),
        ( ($rq | map(select(.b == "other-bash" or .b == "other")) | map(.model_ms) | add // 0) as $u
          | if ($model_ms > 0 and (($u / $model_ms) > 0.25)) then
              { v: "WARN", m: "\((($u / $model_ms) * 100) | round)% of model time is unattributed — the bucket table is behind SKILL.md" } else empty end ),
        if $cost == null then
          { v: "SKIP", m: "no cost-state record: this is a non-interactive (claude -p) transcript, so no cost or session-wide cross-check" } else empty end ]
      | flatten) }
