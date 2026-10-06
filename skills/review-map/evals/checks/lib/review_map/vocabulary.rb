# frozen_string_literal: true

# vocabulary.rb — the causal verbs, read by two checks.
#
# It lived in impact-paths.rb while that was the only check grading an edge. figures.rb grades a
# checkpoint's figure.chain, whose edges carry the same verbs, and two copies of one list are two
# lists the moment someone extends one of them. So it is here, once, and both require it.
#
# Matched on the label's FIRST word so a relation may carry an object: "falls back to",
# "receives proficiency from", "filtered out by".
#
# PASSIVE FORMS ARE IN IT DELIBERATELY. A label reads from the node ABOVE to the node BELOW,
# and half the edges on this page run producer-to-consumer, where the honest verb is passive:
# a changed column is "read by" the query below it, not the other way round. Without them a
# run has to invert the pair to find an active verb, which puts the consumer above the thing
# it consumes and quietly reverses the figure. "ignored by" is the same case one step further
# on, and it is the label for the commonest finding this page carries — a consumer that does
# NOT account for what changed, which is causal even though nothing happens.
#
# Extend this list and report-format.md § Impact paths together. lib/test/test_page.rb reads
# that paragraph and fails when the two disagree, because "keep these in sync" written in two
# comments was the whole of the mechanism before, and it is the kind that drifts.
#
# A LIFECYCLE TRANSITION IS NOT IN THIS VOCABULARY, and must not be added to it. Its label is
# the domain action — "ownership removed", "confirm" — which is a different kind of word: what
# happened to the entity, not how a value travelled. Grading it here would teach a run to write
# "causes" on every transition.

module ReviewMap
  CAUSAL = %w[calls reads writes passes returns defaults falls filters filtered scopes
              renders builds produces serializes receives enqueues broadcasts causes
              read called rendered ignored subscribed].freeze
end
