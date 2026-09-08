# profile-fmt.jq — turns profile.jq's object into the report. Inputs: $t (path), $tl (timeline).
def pad($n): (. | tostring) as $s | $s + ("                                        "[0:($n - ($s|length))] // "");
def lpad($n): (. | tostring) as $s | (("                    "[0:($n - ($s|length))] // "")) + $s;
def pct($d): if $d == 0 then "  -  " else (((. / $d) * 100) | round | tostring) + "%" end;
def tok: if . == null then "-" elif . >= 1000000 then ((. / 100000 | round) / 10 | tostring) + "M"
         elif . >= 1000 then ((. / 100 | round) / 10 | tostring) + "k" else tostring end;

. as $d
| [ "transcript  \($t)",
    "filter      \($d.filter)"
      + (if $d.runs_in_session > 1 then "   ·  run \($d.run) of \($d.runs_in_session) in this session" else "" end),
    "slice       \($d.start) → \($d.end)   \($d.wall_s)s   \($d.requests) requests   \($d.tool_calls) tool calls",
    (if $d.turn_duration_s then "            corroborated by the session's turn_duration \($d.turn_duration_s)s (Δ \(((($d.turn_duration_s - $d.wall_s)|fabs)*10|round)/10)s)" else empty end),
    "",
    "where the time goes",
    "  model            \($d.model_s | lpad(8))s   \($d.model_s | pct($d.wall_s) | lpad(5))    before first token \($d.ttft_s)s  ·  streaming \($d.stream_s)s",
    "  tool execution   \($d.tool_s  | lpad(8))s   \($d.tool_s  | pct($d.wall_s) | lpad(5))"
      + (if $d.session_tool_s then "    cost-state calls it \($d.session_tool_s)s (session-wide)" else "" end),
    "  unaccounted      \($d.unaccounted_s | lpad(8))s   \($d.unaccounted_s | pct($d.wall_s) | lpad(5))",
    "",
    "tokens        output \($d.out_tokens|tok) · thinking \($d.think_tokens|tok) (\($d.think_tokens|pct($d.out_tokens))) · cache read \($d.cache_read|tok) · write \($d.cache_write|tok)",
    "context       ~\($d.context_per_request|tok) tokens per request across \($d.requests) requests",
    (if $d.session_cost_usd then "cost          $\((($d.session_cost_usd)*100|round)/100) · API \($d.session_api_s)s   (both session-wide — a session that also ran other work carries one cost for both)" else empty end),
    "",
    "by activity   a request's model time is charged to the bucket of the tool call it ended in",
    "  " + ("activity"|pad(14)) + ("≈ step"|pad(10)) + ("model"|lpad(9)) + ("tool"|lpad(9)) + ("calls"|lpad(7)) + ("out tok"|lpad(9)) + ("think"|lpad(8)),
    ( $d.buckets[]
      | "  " + (.b|pad(14)) + (.step|pad(10)) + ("\(.model_s)s"|lpad(9)) + ("\(.tool_s)s"|lpad(9))
        + (.n|lpad(7)) + (.out|tok|lpad(9)) + (.think|tok|lpad(8)) ),
    "",
    "  A bucket names the tool a request ended in, not the subject of its reasoning. A row with many",
    "  thinking tokens against a trivial tool call is reasoning parked in front of a cheap call.",
    "  Steps 4, 6 and 8 leave no mechanical trace and interleave with everything else; their cost is",
    "  spread across the rows above and there is no row for them.",
    "",
    "where the money goes   cache reads are context RE-READ: every resident token is billed again,",
    "                       once per request. This is the cost axis; it is not the wall-clock axis.",
    "  " + ("activity"|pad(14)) + ("≈ step"|pad(10)) + ("cache read"|lpad(11)) + ("share"|lpad(7)) + ("ctx/rq"|lpad(9)) + ("out tok"|lpad(9)),
    ( $d.buckets | sort_by(-.cread)[]
      | "  " + (.b|pad(14)) + (.step|pad(10)) + (.cread|tok|lpad(11)) + (.cread|pct($d.cache_read)|lpad(7))
        + ((if .n == 0 then 0 else ((.cread / .n)|round) end)|tok|lpad(9)) + (.out|tok|lpad(9)) ),
    "  " + ("parent total"|pad(24)) + ($d.cache_read|tok|lpad(11)),
    ( if $d.subagents == null then
        "  no subagent transcripts beside this one — nothing spawned, or an older CLI"
      else
        ( "  " + ("subagents (\($d.subagents.agents) agents)"|pad(24)) + ($d.subagents.cache_read|tok|lpad(11))
          + ($d.subagents.cache_read|pct(($d.cache_read + $d.subagents.cache_read))|lpad(7))
          + ((if $d.subagents.requests == 0 then 0 else (($d.subagents.cache_read / $d.subagents.requests)|round) end)|tok|lpad(9))
          + ($d.subagents.out_tokens|tok|lpad(9))
          + "   \($d.subagents.requests) rq  ·  \($d.subagents.models)" )
      end ),
    ( if $d.subagents == null then empty
      else "  " + ("RUN TOTAL"|pad(24)) + (($d.cache_read + $d.subagents.cache_read)|tok|lpad(11)) end ),
    ( if $d.subagents != null and $d.runs_in_session > 1 then
        "  NOTE  subagent tokens are session-wide; this session holds \($d.runs_in_session) runs, so that row is not this run's alone"
      else empty end ),
    "",
    "  Cache reads dominate because context is paid per request, so WHEN a file is loaded matters as",
    "  much as whether. Read this beside the time table, never instead of it: they rank differently",
    "  and a change that helps one can be neutral for the other. See evals/README.md § \"Where the",
    "  time goes\" for why fewer requests is the wall-clock lever, and why that is not this one.",
    "",
    "publish stages   the one boundary that cannot arrive out of order",
    ( $d.stages[] | "  \(.i|lpad(2))  " + (.kind|pad(12)) + (.tool|pad(10)) + "at +\(.at_s)s   \(.out|tok) out tok" ),
    (if ($d.stages|length) == 0 then "  none — nothing was published in this run" else empty end),
    "",
    "slowest \($d.slowest_requests|length) requests   model time, and what the request ended in",
    ( $d.slowest_requests[]
      | "  " + ("\(.model_s)s"|lpad(8)) + "  " + (.out|tok|lpad(7)) + " out / " + (.think|tok|lpad(6)) + " think  "
        + (.tool|pad(9)) + (.b|pad(12)) + .arg ),
    "",
    "slowest \($d.slowest_tools|length) tool calls   execution, including harness overhead",
    ( $d.slowest_tools[]
      | "  " + ("\(.tool_s)s"|lpad(8)) + "  " + (.tool|pad(10)) + (.b|pad(12)) + .arg ),
    "",
    "by tool       " + ([ $d.by_tool[] | "\(.tool) \(.n)/\(.tool_s)s" ] | join(" · ")),
    (if $tl == 1 then
      ([ "", "timeline   at   model   tool  bucket        what it ran / said" ]
       + [ $d.timeline[]
           | "  " + ("+\(.at_s)"|lpad(8)) + ("\(.model_s)s"|lpad(8)) + ("\(.tool_s)s"|lpad(7)) + "  "
             + (.b|pad(14)) + (if .arg == "" then .say else .arg end) ])
     else empty end),
    "",
    ( $d.diagnostics[] | "\(.v)  \(.m)" ),
    (if ($d.diagnostics|length) > 0 then "" else empty end),
    "read evals/README.md § \"Where the time goes\" before quoting any of this"
  ]
| flatten | .[]
