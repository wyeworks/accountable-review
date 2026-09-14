#!/bin/sh
# read-config.sh — read .accountable-review.yml into shell variables.
#
#   Usage: read-config.sh <file> [--prefix CFG_]
#          eval "$(read-config.sh .accountable-review.yml)"
#
# Prints one `PREFIXkey='value'` line per key that is actually present, so a
# caller can eval it and then fall back to its own defaults with ${CFG_x:-...}.
# A key that is absent from the file produces no line — which is the whole point:
# precedence is flags > config > defaults, and a parser that emitted defaults
# would make the middle rung indistinguishable from the bottom one.
#
# The whole schema:
#
#   review_map:
#     mode: brief            # brief | light  (accepted, and decides nothing)
#     effort: high           # high | low  (`normal` accepted, means `low`)
#     delivery:
#       provider: github-artifact
#       retention_days: 30
#       command: ./bin/publish-review-map   # provider: command only
#
# THIS IS NOT A YAML PARSER, and it should not grow into one. It reads exactly
# the keys above at exactly that nesting, which is the entire configuration this
# plugin has. Anything else in the file is an error rather than a shrug: a
# misspelled `retention_days` that parsed as nothing would silently give a team
# the default retention while their file said otherwise, which is the failure
# this file exists to prevent. Adding an option means adding it here, in
# references/config.md, and in whatever reads it — three places on purpose, so a
# configuration surface cannot grow by accident.

set -eu

FILE=${1:-}
PREFIX=CFG_
shift 2>/dev/null || true
while [ $# -gt 0 ]; do
  case $1 in
    --prefix) PREFIX=$2; shift 2 ;;
    *) echo "read-config.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FILE" ]; then
  echo "usage: read-config.sh <file> [--prefix CFG_]" >&2
  exit 2
fi
[ -r "$FILE" ] || { echo "read-config.sh: cannot read $FILE" >&2; exit 1; }

awk -v prefix="$PREFIX" -v file="$FILE" '
  function fail(msg) { printf "read-config.sh: %s:%d: %s\n", file, NR, msg > "/dev/stderr"; bad = 1; exit 1 }
  function emit(k, v) {
    gsub(/'"'"'/, "'"'"'\\'"'"''"'"'", v)
    printf "%s%s='"'"'%s'"'"'\n", prefix, k, v
  }
  {
    line = $0
    sub(/\r$/, "", line)
    if (line ~ /^[[:space:]]*(#|$)/) next

    # Indent, key, value. Trailing comments are stripped only when the value is
    # unquoted — a command containing a # is a legitimate value.
    match(line, /^[[:space:]]*/); indent = RLENGTH
    rest = substr(line, indent + 1)
    if (rest !~ /^[A-Za-z_][A-Za-z0-9_]*:/) fail("expected `key:`, got: " rest)
    key = rest; sub(/:.*$/, "", key)
    val = rest; sub(/^[^:]*:[[:space:]]*/, "", val)
    if (val !~ /^["'"'"']/) sub(/[[:space:]]+#.*$/, "", val)
    sub(/[[:space:]]+$/, "", val)
    if (val ~ /^".*"$/ || val ~ /^'"'"'.*'"'"'$/) val = substr(val, 2, length(val) - 2)

    if (indent == 0) {
      if (key != "review_map") fail("unknown top-level key `" key "` (only `review_map:` exists)")
      section = "review_map"; sub_section = ""
      next
    }
    if (section != "review_map") fail("`" key "` sits outside `review_map:`")

    if (key == "delivery" && val == "") { sub_section = "delivery"; delivery_indent = indent; next }
    if (val == "") fail("`" key "` has no value")
    if (sub_section == "delivery" && indent <= delivery_indent) sub_section = ""

    if (sub_section == "delivery") {
      if (key == "provider") {
        if (val !~ /^[a-z0-9][a-z0-9-]*$/) fail("provider `" val "` is not a provider name")
        emit("provider", val)
      } else if (key == "retention_days") {
        if (val !~ /^[0-9]+$/ || val + 0 < 1 || val + 0 > 90) fail("retention_days must be 1-90, got `" val "`")
        emit("retention_days", val)
      } else if (key == "command") {
        emit("command", val)
      } else fail("unknown key `" key "` under `delivery:`")
      next
    }

    if (key == "mode") {
      # The page has one shape. brief and light are the same page and are taken; full is
      # refused rather than mapped, because it used to mean seven sections and handing back
      # four under the old name is a config that quietly changed meaning.
      if (val == "review") fail("mode `review` is not implemented — use brief or light")
      if (val == "full") fail("mode `full` is not implemented in this version — the Review Map has one shape; use brief or light")
      if (val != "brief" && val != "light") fail("mode must be brief or light, got `" val "`")
      emit("mode", val)
    } else if (key == "effort") {
      if (val == "normal") val = "low"
      if (val != "high" && val != "low") fail("effort must be high or low, got `" val "`")
      emit("effort", val)
    } else fail("unknown key `" key "` under `review_map:`")
  }
' "$FILE"
