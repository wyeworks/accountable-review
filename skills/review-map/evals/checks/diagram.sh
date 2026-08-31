#!/bin/sh
# diagram.sh — every diagram on a page or in a fragment, checked against the design
# system it is supposed to be drawn in.
#
# Diagrams are hand-authored inline SVG, which means they are the one component with no
# generator behind it and no browser to complain. Five things go wrong silently:
#
#   an invented class      styled by nothing, so it renders as an unstyled shape
#   a literal colour       correct in one theme, invisible in the other
#   a surviving {{...}}    a placeholder shipped as content
#   a coordinate off-canvas  a node the reader never sees, in a figure that looks fine
#   a label wider than its box  the most common defect in hand-authored SVG
#
# All five are mechanical. What is not: whether the diagram shows a mechanism a table
# could not, and whether its edges match the real call path. Those are in the case, and
# the PNGs from diagram-shot.sh are how a reader settles the last one.
#
# The vocabulary below is the template's, and it is now exactly the two surviving SVG kinds'
# vocabulary: the ER fragment and the lifecycle. Extend both together — a class added here but
# not to page-template.html has no styles, and one added there but not here is reported
# as invented.
#
# Two class families that used to be here are gone, not renamed. The blast radius is a .blast
# box grid and the boundary chain is a .pipe spine — both CSS components, neither an SVG — so
# `legend` and `box-json` no longer style anything inside an <svg> and would be reported as
# invented if a run reached for them. That is the intended behaviour: a run drawing a blast
# radius as SVG should be told to use the component instead.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); CHECKS_DIR=$HERE; . "$HERE/lib.sh"
parse_args "$@"
require_input

VOCAB="t-title t-col t-dim t-lbl t-edge box box-hd edge edge-dash edge-accent node node-dead lifeline"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

starts=$(grep -n '<svg' "$IN" | cut -d: -f1 || true)
if [ -z "$starts" ]; then
  skip "no diagrams in this input"
  finish
  exit
fi

n=0
for ln in $starts; do
  n=$((n + 1))
  awk -v s="$ln" 'NR>=s { line = $0; if (NR == s) sub(/^.*<svg/, "<svg", line); if (line ~ /<\/svg>/) sub(/<\/svg>.*/, "</svg>", line); print line } /<\/svg>/ { if (NR >= s) exit }' "$IN" > "$TMP/svg-$n"
done
ok "$n diagram(s) found"

# The overflow contract: a diagram lives in figure.wide > .scroller, which is what lets a
# 880-wide figure sit on a phone without the page itself scrolling sideways.
for ln in $starts; do
  ctx_from=$((ln - 4)); [ "$ctx_from" -lt 1 ] && ctx_from=1
  ctx=$(sed -n "${ctx_from},${ln}p" "$IN")
  case $ctx in
    *'class="scroller"'*) : ;;
    *) bad "diagram at line $ln is not inside .scroller — wide content must scroll in its own container, never the page" ;;
  esac
done

i=0
while [ "$i" -lt "$n" ]; do
  i=$((i + 1))
  f=$TMP/svg-$i
  ln=$(echo "$starts" | sed -n "${i}p")

  # The legend is usually the figcaption, which sits OUTSIDE the svg — so the context is
  # the figure, not the drawing. A dashed box with no legend reads as "deleted", which is
  # the opposite of what it means here.
  if grep -q "node-dead" "$f"; then
    len=$(wc -l < "$f" | tr -d " ")
    if sed -n "${ln},$((ln + len + 4))p" "$IN" | sed 's/aria-label="[^"]*"//' | grep -Eqi "legend|dashed|solid"; then
      ok "diagram $i explains its dashed nodes"
    else
      bad "diagram $i uses .node-dead with nothing explaining it — a dashed box unexplained reads as deleted"
    fi
  fi

  # Accessibility and framing, read off the opening tag.
  head_tag=$(tr '\n' ' ' < "$f" | sed -e 's/^.*<svg/<svg/' -e 's/>.*$//')
  case $head_tag in
    *viewBox=*) : ;;
    *) bad "diagram $i has no viewBox — it cannot scale, and the bounds check cannot run" ;;
  esac
  case $head_tag in
    *'role="img"'*) : ;;
    *) bad "diagram $i has no role=\"img\"" ;;
  esac
  case $head_tag in
    *aria-label=*'{{'*) bad "diagram $i ships a placeholder aria-label" ;;
    *'aria-label=""'*) bad "diagram $i has an empty aria-label" ;;
    *aria-label=*) : ;;
    *) bad "diagram $i has no aria-label — the one part of a figure a screen reader can use" ;;
  esac

  # The four analyses that need the geometry. One awk pass over the flattened SVG,
  # emitting only problems, tagged so the shell can print a single PASS per category.
  awk -v vocab="$VOCAB" '
    { body = body " " $0 }
    END {
      gsub(/\r/, " ", body)
      split(vocab, v, " "); for (k in v) known[v[k]] = 1

      # viewBox bounds. Anything outside them is drawn where no reader will look.
      if (match(body, /viewBox="[^"]*"/)) {
        vb = substr(body, RSTART + 9, RLENGTH - 10)
        split(vb, b, /[ ,]+/); vw = b[3] + 0; vh = b[4] + 0
      }

      rest = body
      while (match(rest, /<[a-zA-Z]+[^>]*>/)) {
        el = substr(rest, RSTART, RLENGTH)
        after = substr(rest, RSTART + RLENGTH)
        rest = after
        tag = el; sub(/^</, "", tag); sub(/[ \/>].*/, "", tag)

        # Invented classes: styled by nothing, so they render as bare shapes.
        if (match(el, /class="[^"]*"/)) {
          cl = substr(el, RSTART + 7, RLENGTH - 8)
          nc = split(cl, cs, " ")
          for (j = 1; j <= nc; j++)
            if (cs[j] != "" && !known[cs[j]] && !seenclass[cs[j]]++)
              print "ERR\tvocab\tclass \"" cs[j] "\" is not in the template vocabulary — nothing styles it"
        }

        # Literal colours. A colour spelled out here is correct in one theme and wrong in
        # the other; the classes exist so it never has to be.
        for (a = 1; a <= 2; a++) {
          attr = (a == 1 ? "fill" : "stroke")
          if (match(el, attr "=\"[^\"]*\"")) {
            val = substr(el, RSTART + length(attr) + 2, RLENGTH - length(attr) - 3)
            if (val != "none" && val !~ /^var\(/ && val !~ /^url\(/ && val != "currentColor" && !seencol[val]++)
              print "ERR\tcolour\t" attr "=\"" val "\" is a literal colour — use a class, or var(--token)"
          }
        }
        if (match(el, /style="[^"]*"/)) {
          st = substr(el, RSTART + 7, RLENGTH - 8)
          if (st ~ /(fill|stroke|color)[ ]*:[ ]*(#|rgb|hsl)/ && !seenstyle++)
            print "ERR\tcolour\tinline style declares a literal colour: " st
        }


        # Collect geometry for the bounds and label passes.
        if (tag == "rect") {
          rn++
          rx[rn] = attrnum(el, "x"); ry[rn] = attrnum(el, "y")
          rw[rn] = attrnum(el, "width"); rh[rn] = attrnum(el, "height")
        }
        if (tag == "text") {
          tn++
          tx[tn] = attrnum(el, "x"); ty[tn] = attrnum(el, "y")
          tanchor[tn] = "start"
          if (el ~ /text-anchor="middle"/) tanchor[tn] = "middle"
          if (el ~ /text-anchor="end"/)    tanchor[tn] = "end"
          tsize[tn] = 12
          if (el ~ /class="[^"]*t-title/) tsize[tn] = 13
          if (el ~ /class="[^"]*t-col/)   tsize[tn] = 11
          if (el ~ /class="[^"]*t-dim/)   tsize[tn] = 10.5
          if (el ~ /class="[^"]*t-lbl/)   tsize[tn] = 10
          if (el ~ /class="[^"]*t-edge/)  tsize[tn] = 10.5
          content = after
          sub(/<.*/, "", content)
          gsub(/^[ \t]+|[ \t]+$/, "", content)
          ttext[tn] = content
        }

        # Explicit coordinates, checked hard. Path data is checked loosely below,
        # because pairing numbers off a d= attribute is a guess about the commands.
        if (vw > 0) {
          split("x y x1 y1 x2 y2 cx cy", coords, " ")
          for (c in coords) {
            a2 = coords[c]
            if (match(el, "(^|[ \t])" a2 "=\"-?[0-9.]+\"")) {
              val = attrnum(el, a2)
              lim = (a2 ~ /^(y|cy)/) ? vh : vw
              if (val < 0 || val > lim)
                print "ERR\tbounds\t<" tag "> has " a2 "=" val ", outside the " vw "x" vh " viewBox"
            }
          }
          if (tag == "rect" && rx[rn] + rw[rn] > vw + 0.5)
            print "ERR\tbounds\ta rect runs to x=" rx[rn] + rw[rn] ", past the " vw "-wide viewBox"
          if (match(el, /d="[^"]*"/)) {
            d = substr(el, RSTART + 3, RLENGTH - 4)
            gsub(/[A-Za-z,]/, " ", d)
            np = split(d, ps, /[ ]+/)
            k = 0
            for (p = 1; p <= np; p++) {
              if (ps[p] == "") continue
              k++
              lim = (k % 2 == 0) ? vh : vw
              if (ps[p] + 0 > lim && !seenpath++)
                print "WRN\tbounds\ta path coordinate reads " ps[p] " against a limit of " lim " — check the far edge of the figure"
            }
          }
        }
      }

      # Placeholders, checked against the whole drawing: the ones that ship are usually text
      # content, not attributes, so an element-by-element pass misses exactly the common case.
      if (body ~ /{{/)
        print "ERR\tplaceholder\ta {{PLACEHOLDER}} survives inside the diagram"

      # Labels against the boxes. Monospace, so width is close to 0.6 per character; crude,
      # and a WARN, but these are the defects that actually ship. Two of them, and the second
      # was found by looking at a PNG this pass had just called clean: a label INSIDE a box can
      # be wider than the box, and a label outside every box can still run underneath one.
      for (t = 1; t <= tn; t++) {
        if (ttext[t] == "") continue
        w = length(ttext[t]) * tsize[t] * 0.6
        left = tx[t]
        if (tanchor[t] == "middle") left = tx[t] - w / 2
        if (tanchor[t] == "end")    left = tx[t] - w
        inside = 0
        for (r = 1; r <= rn; r++) {
          if (rw[r] <= 0) continue
          if (ty[t] < ry[r] || ty[t] > ry[r] + rh[r]) continue
          if (tx[t] >= rx[r] && tx[t] <= rx[r] + rw[r]) {
            inside = 1
            if (left + w > rx[r] + rw[r] - 2 || left < rx[r] + 2)
              print "WRN\tlabel\t\"" substr(ttext[t], 1, 40) "\" is about " int(w) "px wide in a box " int(rw[r]) "px wide — likely spills"
            break
          }
        }
        if (inside) continue
        for (r = 1; r <= rn; r++) {
          if (rw[r] <= 0) continue
          if (ty[t] < ry[r] || ty[t] > ry[r] + rh[r]) continue
          if (left + w > rx[r] && left < rx[r] + rw[r]) {
            print "WRN\tlabel\t\"" substr(ttext[t], 1, 40) "\" is about " int(w) "px wide and runs under a box at x=" int(rx[r]) " — an edge label wider than its gap"
            break
          }
        }
      }

    }
    function attrnum(s, a,   m) {
      if (match(s, "(^|[ \t])" a "=\"-?[0-9.]+\"")) {
        m = substr(s, RSTART, RLENGTH)
        sub(/^.*="/, "", m); sub(/"$/, "", m)
        return m + 0
      }
      return -1
    }
  ' "$f" > "$TMP/out-$i"

  for cat in vocab colour placeholder bounds label; do
    if grep -q "	$cat	" "$TMP/out-$i"; then
      while IFS='	' read -r sev c msg; do
        [ "$c" = "$cat" ] || continue
        case $sev in
          ERR) bad "diagram $i · $msg" ;;
          WRN) maybe "diagram $i · $msg" ;;
        esac
      done < "$TMP/out-$i"
    else
      case $cat in
        vocab)       ok "diagram $i uses only template classes" ;;
        colour)      ok "diagram $i takes every colour from a class" ;;
        placeholder) ok "diagram $i has no placeholders left" ;;
        bounds)      ok "diagram $i draws inside its viewBox" ;;
        label)       ok "diagram $i labels fit their boxes" ;;
      esac
    fi
  done
done

# The budget, which only means anything across a whole page: one per section, a second
# only for a genuinely different mechanism.
if [ "$IN_KIND" != page ]; then
  skip "diagram budget: it is a per-section count, so a fragment cannot settle it"
else
  awk '
    /<section [^>]*id="/ { id = $0; sub(/.*id="/, "", id); sub(/".*/, "", id); count[id] = count[id] + 0; cur = id }
    /<\/section>/ { cur = "" }
    /<svg/ { if (cur != "") count[cur]++ }
    END { for (s in count) if (count[s] > 0) print count[s] "\t" s }
  ' "$IN" > "$TMP/budget"
  over=0
  while IFS='	' read -r c s; do
    [ -n "${c:-}" ] || continue
    if [ "$c" -ge 3 ]; then
      bad "section \"$s\" carries $c diagrams — the budget is one, and a second only for a different mechanism"
      over=1
    elif [ "$c" -eq 2 ]; then
      maybe "section \"$s\" carries 2 diagrams — legitimate only if they show different mechanisms (ER plus lifecycle is the usual case)"
      over=1
    fi
  done < "$TMP/budget"
  [ "$over" -eq 0 ] && ok "diagram budget respected in every section"
fi

finish
