# Flow split — monolith-guard-chain

Grouping principle: **one flow per question the change answers differently**, which here is
*who is affected* — not one flow per directory and not one per file.

```
Flow A — Only an accepted institute role sends you to /steward   primary
Flow B — Accepting a chapter-steward invite stops writing account_type   primary
Flow C — Chapter stewards are sent to their chapter, not to /steward   primary
```

Every flow cuts across the controller, the model and the tests.
`app/controllers/application_controller.rb` appears in two of them and
`test/controllers/steward_section_redirect_test.rb` in two, because the files are not the
units of behaviour here. A directory split would have put the redirect fix and the invite's
write in the same bucket — "controllers" and "models" — and hidden that **C is the only flow
with unresolved behaviour**, which is the single most useful thing the page can tell a
reviewer.

All seven paths are **primary**. There is no supporting refactor and nothing independently
reviewable, so the primary/supporting/secondary split is not worth breaking out.

## Affected but unchanged, per flow

This is the ground truth. Each entry is true, cited, and absent from the diff.

**Flow A**

| Where | Why it is affected |
|---|---|
| `app/controllers/application_controller.rb:64-73` | `require_active_plan`, the sibling guard in the same chain, still returns early on `steward?`. The fix removed the coupling from one of three guards |
| `app/controllers/application_controller.rb:80-90` | `require_profile_setup`, same. A stray flag continues to exempt its holder from both walls, which is now the only remaining effect of holding it |
| `app/controllers/steward/base_controller.rb:18-22` | `authorize_steward!` — the admission test the fix was aligned to. Read it second or the fix looks arbitrary |
| `app/controllers/steward/base_controller.rb:24-29` | `require_steward_profile_setup` keys on `steward?` but runs only inside a section that now admits nobody holding only the flag, so it is unreachable for that population |

**Flow B**

| Where | Why it is affected |
|---|---|
| `app/services/matching/eligibility_filter.rb:35` and `:16` | Both the collection filter and the pair check reject on `steward?`. Chapter stewards accepted after this deploys become candidates for recommendations |
| `app/models/user.rb:18` | `scope :recommendable` applies the same exclusion in SQL, and four jobs reach it: `app/jobs/action_items/generate_all_job.rb:6`, `app/jobs/goals/send_reminder_notifications_job.rb:6`, `app/jobs/suggestions/generate_teams_job.rb:7`, `app/jobs/suggestions/generate_weekly_job.rb:6` |
| `app/models/user.rb:21` | `general_recommendations_eligible` *also* excludes `plan: :community`, which this same diff now grants unpaid stewards — so the two scopes disagree about exactly this population |
| `app/models/user.rb:19` | `scope :chapter_stewards` is the natural home for that exclusion if it is wanted, and has no callers anywhere |
| `app/models/user.rb:55-61` | `switch_to_free!` gains a second caller. Its own comment says "the controller guards genuine Stripe subscribers out of this path" — and the new call site is not that controller |
| `app/models/user.rb:63-65` | Why the guard nevertheless holds: `has_paid_subscription?` is `stripe_customer_id.present? && plan_active? && !in_trial?`, and the new call site runs only `unless plan_active?`, so it is false for everyone it touches. **By conjunction, not by design** — drop the `plan_active?` term and this call site loses its guard silently |
| `app/controllers/memberships_controller.rb:12-20` | The controller the comment means, doing the check the comment describes |

**Flow C**

| Where | Why it is affected |
|---|---|
| `app/controllers/chapters_controller.rb:1-13` | The new destination skips `require_active_plan` and `redirect_admin_to_admin_section` — but **not** `require_profile_setup` |
| `app/controllers/application_controller.rb:94-97` | And `chapters` is absent from `profile_setup_not_required?`, while it *is* present in `plan_not_required?` at `:75-78`. So a chapter steward with an incomplete profile is redirected on to `step_profile_setup_path` instead of landing on their chapter |
| `app/models/chapter.rb:89-98` | `generate_steward_invite!` raises for an existing member whose profile is already complete, so an invitee is by construction a new or half-set-up account — the exact population the guard above intercepts |
| `app/models/chapter.rb:75-81` | `can_manage?` returns true on `steward_id == user.id`, so `authorize_leader!` passes with no `ChapterMembership` at all. The one downstream guard that does the right thing without help |
| `app/controllers/chapters_controller.rb:87-92` | `load_management` reads *approved memberships*, so a freshly accepted steward sees a roster that does not include themselves. `accept_steward_invite!` creates no membership, unlike `Chapter#add_leader!` at `app/models/chapter.rb:29-33`, which the self-serve creation path uses |
| `test/test_helper.rb:7-27` | An unchanged monkey-patch adds an `after_create` that completes every test user's profile. It runs after `User`'s own `after_create :build_default_profile` (`app/models/user.rb:33`), so it always fires for a user built with `User.create!` — which is how the new redirect test builds both of its subjects (`test/controllers/steward_section_redirect_test.rb:21`, `:38`). Its `assert_response :success` on the manage page therefore passes from a state no real invitee is in |

**One refinement, from the second live run against this fixture.** An earlier version of the row
above said *no* test in the suite can observe the interception. That is too strong, and the run said
so. Rails loads `test/fixtures/*.yml` with raw inserts, so **fixture users never fire the
`after_create` patch** — and there is no `profiles.yml`, so they have no `Profile` row at all. For
them `current_user.profile&.setup_completed?` is `nil`, the guard falls through, and the redirect
*would* be observable. The two tests that use fixture users
(`test/controllers/steward_invites_controller_test.rb:6`, `:25`) simply never follow the redirect to
find out; they assert the target and stop. So the accurate claim is narrower and more useful: the
blinding is specific to `User.create!`, a fixture-based test is the thing that would have caught
this, and the suite contains one that is two lines away from doing so.

## Cross-cutting, for § 5

Only what genuinely spans flows:

- **The global `before_action` chain.** Five filters, in order, at
  `app/controllers/application_controller.rb:4-8`. This PR changes the *condition* of the
  third. Order unchanged, none added or removed, no `skip_before_action` list touched — which
  is exactly why the change reaches so far: three of the five read `account_type`, and two
  still do.
- **No authorization library**, so nothing reconciles two definitions of the same word.
- **Background jobs**: no job class or argument changed, so nothing enqueued is affected.
  What changes is job *input* — see Flow B.
- **Deploy**: one process, no migration, so no ordering window and no old/new schema
  question. Forward-only; rolling back the code restores the loop.
- **Feature flags**: no default changed. `Flipper.enable(:chapter_hubs)` appears only inside
  the new test (`test/controllers/steward_section_redirect_test.rb:51`), and `manage` is not
  among the actions `require_chapter_hubs_flag!` gates
  (`app/controllers/chapters_controller.rb:10`) — so it should not matter, yet the test
  author evidently found it necessary.
- **Three writes, no transaction.** `accept_steward_invite!` does `user.update!`, then
  `user.switch_to_free!` (a second `update!`), then `save!` on the chapter — three statements
  with no `transaction` around them (`app/models/chapter.rb:100-114`). The sequence was
  already non-transactional; this change adds a second user write to it. Compare
  `ChaptersController#create`, which does wrap its two
  (`app/controllers/chapters_controller.rb:29-32`), and `InstituteRole#accept!`
  (`app/models/institute_role.rb:11-14`).
- **Application-versus-database invariants.** `db/schema.rb:60` declares
  `t.integer "account_type", default: 0, null: false` with **no check constraint**, so the
  enum's two values are a Ruby-side rule only. `index_chapters_on_steward_id`
  (`db/schema.rb:26`) is **not unique**, so one user may steward many chapters, which is why
  `Chapter.find_by(steward_id: resource.id)` has no defined ordering. At sign-up there is at
  most one, so that is latent rather than live.

## Not a flow

No persistence section and no endpoint-contract section of their own. There is no schema
change to give one a subject, and the "API surface" of a server-rendered monolith is the
guard chain and the set of redirect destinations — which belongs inside the flow that owns
it. What acceptance writes is Flow B's; where the browser is sent is Flow C's.
