# Goal and use cases — monolith-guard-chain

## What it is for

Two independent facts about a user decided two different things, and "steward" names both.
`users.account_type` is an enum with exactly two values, `member` and `steward`
(`app/models/user.rb:7`). An accepted `InstituteRole` is a row in another table
(`app/models/user.rb:73`). Before this change the redirect *into* `/steward` read the column
and the guard *inside* it read the role, so anyone holding the column without the role
bounced between `/` and `/steward` until the browser gave up.

This PR narrows the push to match the admission test, and stops the chapter-steward invite
from writing that column at all.

Evidence, ranked as step 4 ranks it:

| Source | What it establishes |
|---|---|
| `test/controllers/steward_section_redirect_test.rb` | The only written statement of intended behaviour, and 68 of the 118 added lines. Names the loop and asserts it is gone |
| `app/controllers/application_controller.rb:39-42` | Four lines of new comment recording *why*, which is the part a future reader needs |
| `app/models/chapter.rb:104-108` | What acceptance writes now, and the four-line comment saying what it deliberately stopped writing |
| `test/models/chapter_test.rb:31-34` | An existing assertion flipped from `assert new_user.steward?` to `assert_not`. The sharpest single statement of intent in the diff |
| Commit message | Three bullets, one per production change. Confirms the subject and gives the *why* for each |
| PR description | None exists |

## Use cases

```
Use case A — A signed-in user whose account_type is steward but who holds no
             accepted institute role
Before: every authenticated page load bounced / <-> /steward until the browser
gave up. After: the redirect never fires for them.

GET / (any authenticated page)
  → ApplicationController#redirect_steward_to_steward_section
      was: true when account_type == steward
      now: true only for an accepted InstituteRole
  → redirect_to steward_root_path
  → Steward::BaseController#authorize_steward!   (unchanged)
  → redirect_to authenticated_root_path          (and back to the top)
```

```
Use case B — Someone accepts a chapter-steward invite
Before: acceptance set account_type: :steward, so the invite itself manufactured
use case A. After: it leaves the column alone and moves a user with no active
plan onto the free Community plan.

GET /steward_invites/:token
  → StewardInvitesController#show      (email must match steward_invite_email)
  → Chapter#accept_steward_invite!
  → users.chapter_steward = true
    users.plan = community  if !plan_active?
    chapters.steward_id = user.id
    (users.account_type is no longer written here)
```

```
Use case C — A chapter steward arrives somewhere after accepting or signing up
Before: both paths sent them to steward_root_path, which they cannot enter.
After: both send them to manage_chapter_path.

StewardInvitesController#show            → manage_chapter_path(@chapter)
Users::RegistrationsController
  #after_sign_up_path_for                → manage_chapter_path(
                                             Chapter.find_by(steward_id: resource.id))
  → ChaptersController#manage
      authorised by Chapter#can_manage?, which accepts the steward_id owner
```

## Stated gaps

- **Nothing touches existing rows.** There is no migration and no backfill, so any user
  already holding `account_type: :steward` without an accepted role keeps it. For them this
  PR stops the loop and changes nothing else. Whether such rows exist is not answerable from
  this repository.
- **Use case C is the one with unresolved behaviour.** Whether a brand-new chapter steward
  actually *sees* `manage_chapter_path` depends on a guard neither path changed, and no test
  in this diff settles it. This is the finding, not a footnote — see `flows.md`.
- **The word is the bug.** "Steward" means the enum column, an accepted `InstituteRole`, and
  `chapters.steward_id`, in one codebase with no authorization library to reconcile them.
  After this change `account_type: :steward` means less than it did: it still exempts its
  holder from two guards but no longer routes them anywhere. That is a design observation,
  and the register for it is neutral — not a complaint about the schema.
