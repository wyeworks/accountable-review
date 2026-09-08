#!/bin/sh
# links-repo.sh — the one golden fixture that has to be a real git repository.
#
#   Usage: links-repo.sh <dir>        # builds it, prints the base SHA on stdout
#
# link-form.rb's third rule asks scripts/diff-render.sh which files GitHub will render, and that
# question is answered by git: check-attr resolution, numstat, the size of a path's own diff.
# searches-repo/ is a plain directory because searches.rb only greps; this one cannot be, and a
# rule that could only ever SKIP in self-test-cases.txt is exactly what that file exists to
# prevent.
#
# Two commits, and deliberately the smallest pair that separates the two verdicts:
#
#   db/structure.sql      one added line, and linguist-generated=true in .gitattributes, so
#                         GitHub withholds the diff. This is the case no size rule catches, and
#                         the one a real Rails page cites — a schema dump is where the invariants
#                         section reads.
#   app/models/order.rb   one added line and nothing else, so its diff renders and a citation
#                         into it keeps the diff anchor.
#
# Every commit field is FIXED, so the base SHA is the same on every machine and in every run.
# checks/frozen.rb replays the rows that use this fixture, and a corpus whose recorded output
# moved with the clock would report the weather as drift.

set -eu

DIR=${1:?usage: links-repo.sh <dir>}
mkdir -p "$DIR/db" "$DIR/app/models"

export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.com
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.com
export GIT_AUTHOR_DATE='2026-01-01T00:00:00+00:00'
export GIT_COMMITTER_DATE='2026-01-01T00:00:00+00:00'

cd "$DIR"
git init -q .
git config commit.gpgsign false

printf 'db/structure.sql linguist-generated=true\n' > .gitattributes
printf 'CREATE TABLE orders (\n  id bigint NOT NULL\n);\n' > db/structure.sql
printf 'class Order < ApplicationRecord\nend\n' > app/models/order.rb
git add -A
git commit -qm base
git rev-parse HEAD

printf '  state character varying,\n' >> db/structure.sql
printf '# one more line\n' >> app/models/order.rb
git add -A
git commit -qm head
