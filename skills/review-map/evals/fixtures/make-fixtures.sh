#!/bin/sh
# make-fixtures.sh — build the target repositories the evals run against.
#
#   Usage: make-fixtures.sh [dest]        (default: $TMPDIR/review-map-fixtures)
#
# The skill needs a repository with a diff to review, so every eval needs one.
# Rather than commit nested git repos, this script materialises them. It is
# deterministic: same fixtures every run, so a failing expectation means the skill
# changed, not the input.
#
# Each fixture plants findings the skill is supposed to surface, listed in
# ../evals.json as expectations. That is what makes these evals rather than vibes:
# there is a right answer, written down, and it is not in the diff.

set -eu

DEST=${1:-${TMPDIR:-/tmp}/review-map-fixtures}
rm -rf "$DEST"
mkdir -p "$DEST"

init_repo() {
  git -C "$1" init -q .
  git -C "$1" config user.email fixtures@example.com
  git -C "$1" config user.name Fixtures
  git -C "$1" config commit.gpgsign false
}
commit() { git -C "$1" add -A; git -C "$1" commit -q -m "$2"; }

# ---------------------------------------------------------------------------
# F1 · rails-only-small
#
# Five changed files, no frontend, no remote at all — deep-link rung 4, so
# citations must be plain text and Part 5 must be omitted rather than emptied.
#
# Planted:
#   · app/queries/active_projects.rb is NOT in the diff but scopes the exact
#     collection archival changes the meaning of. Step 5 has to find it.
#   · The migration adds archived_at while the model gains a slug uniqueness
#     validation with no unique index behind it — the app-vs-DB invariant gap.
# ---------------------------------------------------------------------------
F1=$DEST/rails-only-small
mkdir -p "$F1"/app/models "$F1"/app/controllers "$F1"/app/queries "$F1"/spec/models "$F1"/db/migrate "$F1"/config
init_repo "$F1"

cat > "$F1/config/application.rb" <<'EOF'
require "rails/all"

module Timesheet
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
  end
end
EOF
cat > "$F1/Gemfile" <<'EOF'
source "https://rubygems.org"
gem "rails", "~> 7.1"
group :development, :test do
  gem "rspec-rails"
end
EOF

# A real Rails app has a lock file, and the skill reads its exact versions rather than the
# Gemfile's constraint: `~> 7.1` does not say which series is installed, and every doc link
# on the page is pinned with the answer. A fixture without one cannot exercise pinning at all.
cat > "$F1/Gemfile.lock" <<'EOF'
GEM
  remote: https://rubygems.org/
  specs:
    activerecord (7.1.6)
    activesupport (7.1.6)
    rails (7.1.6)
    rspec-rails (7.1.1)

PLATFORMS
  ruby

DEPENDENCIES
  rails (~> 7.1)
  rspec-rails

BUNDLED WITH
   2.5.16
EOF
cat > "$F1/app/models/project.rb" <<'EOF'
class Project < ApplicationRecord
  has_many :time_entries, dependent: :restrict_with_error

  validates :name, presence: true
end
EOF
cat > "$F1/app/controllers/projects_controller.rb" <<'EOF'
class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :update]

  def index
    render json: ActiveProjects.new.call
  end

  def show
    render json: @project
  end

  def update
    if @project.update(project_params)
      render json: @project
    else
      render json: { errors: @project.errors }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name)
  end
end
EOF
# Not in the diff, and the whole point of the fixture.
cat > "$F1/app/queries/active_projects.rb" <<'EOF'
# Every selectable-project list in the app goes through here.
class ActiveProjects
  def call
    Project.where(discarded_at: nil).order(:name)
  end
end
EOF
cat > "$F1/spec/models/project_spec.rb" <<'EOF'
require "rails_helper"

RSpec.describe Project do
  it "requires a name" do
    expect(described_class.new(name: nil)).not_to be_valid
  end
end
EOF
cat > "$F1/db/schema.rb" <<'EOF'
ActiveRecord::Schema[7.1].define(version: 2025_12_01_000000) do
  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug"
    t.datetime "discarded_at"
    t.timestamps
  end
end
EOF
commit "$F1" "base"

cat > "$F1/db/migrate/20260101000000_add_archived_at_to_projects.rb" <<'EOF'
class AddArchivedAtToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :archived_at, :datetime
    add_index :projects, :archived_at
  end
end
EOF
cat > "$F1/app/models/project.rb" <<'EOF'
class Project < ApplicationRecord
  has_many :time_entries, dependent: :restrict_with_error

  validates :name, presence: true
  # No unique index backs this: two concurrent requests can both pass it.
  validates :slug, uniqueness: true

  scope :archived, -> { where.not(archived_at: nil) }

  def archive!
    update!(archived_at: Time.current)
  end
end
EOF
cat > "$F1/app/controllers/projects_controller.rb" <<'EOF'
class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :update, :archive]

  def index
    render json: ActiveProjects.new.call
  end

  def show
    render json: @project
  end

  def update
    if @project.update(project_params)
      render json: @project
    else
      render json: { errors: @project.errors }, status: :unprocessable_entity
    end
  end

  def archive
    @project.archive!
    render json: @project
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name)
  end
end
EOF
cat > "$F1/spec/models/project_spec.rb" <<'EOF'
require "rails_helper"

RSpec.describe Project do
  it "requires a name" do
    expect(described_class.new(name: nil)).not_to be_valid
  end

  describe "#archive!" do
    it "stamps archived_at" do
      project = create(:project)
      project.archive!
      expect(project.archived_at).to be_present
    end

    it "keeps historical time entries" do
      project = create(:project)
      entry = create(:time_entry, project: project)
      project.archive!
      expect(entry.reload.project).to eq(project)
    end
  end
end
EOF
cat > "$F1/db/schema.rb" <<'EOF'
ActiveRecord::Schema[7.1].define(version: 2026_01_01_000000) do
  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug"
    t.datetime "discarded_at"
    t.datetime "archived_at"
    t.timestamps
    t.index ["archived_at"], name: "index_projects_on_archived_at"
  end
end
EOF
git -C "$F1" checkout -q -b add-project-archival
commit "$F1" "Add project archival"

# ---------------------------------------------------------------------------
# F2 · monorepo-contract
#
# Rails API under api/, Next.js client under web/, both sides in one diff, and a
# remote configured but nothing pushed — deep-link rung 3, so citations are plain
# text AND the page has to say why.
#
# Planted:
#   · api serializes archived_at as nullable; web/src/types/project.ts declares
#     archivedAt: string — non-null. The mismatch has no compiler behind it.
#   · The archive endpoint can return 422; nothing in web/ handles it.
#   · web/src/queries/selectableProjects.ts is NOT in the diff and filters the
#     project list without knowing about archival.
# ---------------------------------------------------------------------------
F2=$DEST/monorepo-contract
mkdir -p "$F2"/api/app/models "$F2"/api/app/serializers "$F2"/api/app/controllers "$F2"/api/config \
         "$F2"/api/db/migrate "$F2"/api/spec/requests \
         "$F2"/web/src/types "$F2"/web/src/hooks "$F2"/web/src/queries "$F2"/web/src/components
init_repo "$F2"

cp "$F1/Gemfile" "$F2/api/Gemfile"
cp "$F1/Gemfile.lock" "$F2/api/Gemfile.lock"
cat > "$F2/api/config/application.rb" <<'EOF'
require "rails/all"

module Api
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
  end
end
EOF
cat > "$F2/web/package.json" <<'EOF'
{
  "name": "web",
  "private": true,
  "dependencies": { "next": "15.0.0", "react": "19.0.0", "@tanstack/react-query": "5.0.0" }
}
EOF
cat > "$F2/web/next.config.js" <<'EOF'
module.exports = { reactStrictMode: true };
EOF
cat > "$F2/api/app/models/project.rb" <<'EOF'
class Project < ApplicationRecord
  validates :name, presence: true
end
EOF
cat > "$F2/api/app/serializers/project_serializer.rb" <<'EOF'
class ProjectSerializer
  def initialize(project)
    @project = project
  end

  def as_json(*)
    { id: @project.id, name: @project.name }
  end
end
EOF
cat > "$F2/api/app/controllers/projects_controller.rb" <<'EOF'
class ProjectsController < ApplicationController
  def index
    render json: Project.all.map { |p| ProjectSerializer.new(p).as_json }
  end
end
EOF
cat > "$F2/api/spec/requests/projects_spec.rb" <<'EOF'
require "rails_helper"

RSpec.describe "Projects" do
  it "lists projects" do
    get "/api/projects"
    expect(response).to have_http_status(:ok)
  end
end
EOF
cat > "$F2/web/src/types/project.ts" <<'EOF'
export type Project = {
  id: number;
  name: string;
};
EOF
cat > "$F2/web/src/hooks/useProjects.ts" <<'EOF'
import { useQuery } from "@tanstack/react-query";
import type { Project } from "../types/project";

export function useProjects() {
  return useQuery<Project[]>({
    queryKey: ["projects"],
    queryFn: async () => {
      const res = await fetch("/api/projects");
      if (!res.ok) throw new Error("failed to load projects");
      return res.json();
    },
  });
}
EOF
# Not in the diff. Filters the project list, and archival changes what belongs in it.
cat > "$F2/web/src/queries/selectableProjects.ts" <<'EOF'
import type { Project } from "../types/project";

// Used by every project picker in the app.
export function selectableProjects(projects: Project[]): Project[] {
  return projects.filter((p) => p.name.length > 0);
}
EOF
cat > "$F2/web/src/components/ProjectSelector.tsx" <<'EOF'
"use client";

import { useProjects } from "../hooks/useProjects";
import { selectableProjects } from "../queries/selectableProjects";

export function ProjectSelector() {
  const { data, error } = useProjects();
  if (error) return <p>Something went wrong.</p>;
  return (
    <select>
      {selectableProjects(data ?? []).map((p) => (
        <option key={p.id} value={p.id}>{p.name}</option>
      ))}
    </select>
  );
}
EOF
commit "$F2" "base"

cat > "$F2/api/db/migrate/20260101000000_add_archived_at_to_projects.rb" <<'EOF'
class AddArchivedAtToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :archived_at, :datetime
  end
end
EOF
cat > "$F2/api/app/models/project.rb" <<'EOF'
class Project < ApplicationRecord
  validates :name, presence: true

  scope :archived, -> { where.not(archived_at: nil) }

  def archive!
    raise ArchiveError, "project has running timers" if time_entries.running.any?

    update!(archived_at: Time.current)
  end

  class ArchiveError < StandardError; end
end
EOF
cat > "$F2/api/app/serializers/project_serializer.rb" <<'EOF'
class ProjectSerializer
  def initialize(project)
    @project = project
  end

  def as_json(*)
    {
      id: @project.id,
      name: @project.name,
      # nil for every project that has never been archived
      archived_at: @project.archived_at&.iso8601,
    }
  end
end
EOF
cat > "$F2/api/app/controllers/projects_controller.rb" <<'EOF'
class ProjectsController < ApplicationController
  def index
    render json: Project.all.map { |p| ProjectSerializer.new(p).as_json }
  end

  def archive
    project = Project.find(params[:id])
    project.archive!
    render json: ProjectSerializer.new(project).as_json
  rescue Project::ArchiveError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
EOF
cat > "$F2/api/spec/requests/projects_spec.rb" <<'EOF'
require "rails_helper"

RSpec.describe "Projects" do
  it "lists projects" do
    get "/api/projects"
    expect(response).to have_http_status(:ok)
  end

  it "archives a project" do
    project = create(:project)
    post "/api/projects/#{project.id}/archive"
    expect(response).to have_http_status(:ok)
  end
end
EOF
cat > "$F2/web/src/types/project.ts" <<'EOF'
export type Project = {
  id: number;
  name: string;
  archivedAt: string;
};
EOF
cat > "$F2/web/src/hooks/useProjects.ts" <<'EOF'
import { useQuery, useMutation } from "@tanstack/react-query";
import type { Project } from "../types/project";

export function useProjects() {
  return useQuery<Project[]>({
    queryKey: ["projects"],
    queryFn: async () => {
      const res = await fetch("/api/projects");
      if (!res.ok) throw new Error("failed to load projects");
      return res.json();
    },
  });
}

export function useArchiveProject() {
  return useMutation({
    mutationFn: async (id: number) => {
      const res = await fetch(`/api/projects/${id}/archive`, { method: "POST" });
      if (!res.ok) throw new Error("failed to archive project");
      return res.json();
    },
  });
}
EOF
git -C "$F2" remote add origin https://github.com/acme/timesheet.git
git -C "$F2" checkout -q -b project-archival
commit "$F2" "Archive projects, backend and client"

# ---------------------------------------------------------------------------
# F3 · trivial
#
# One typo. The skill should say a page is not worth generating and offer to stop.
# ---------------------------------------------------------------------------
F3=$DEST/trivial
mkdir -p "$F3/config"
init_repo "$F3"
cp "$F1/config/application.rb" "$F3/config/application.rb"
cp "$F1/Gemfile" "$F3/Gemfile"
cp "$F1/Gemfile.lock" "$F3/Gemfile.lock"
printf '# Timesheet\n\nA time tracking aplication.\n' > "$F3/README.md"
commit "$F3" "base"
printf '# Timesheet\n\nA time tracking application.\n' > "$F3/README.md"
git -C "$F3" checkout -q -b fix-typo
commit "$F3" "Fix typo in README"


# ---------------------------------------------------------------------------
# F4 · monolith-guard-chain
#
# A server-rendered Rails monolith — Minitest, Hotwire, ERB, no client package —
# so the behaviour flows have to describe a guard chain and a set of redirect
# destinations rather than a JSON contract. Seven files: four production lines
# and 102 lines of test.
#
# A GitHub remote is configured and nothing is pushed, so this is deep-link rung 3,
# same as F2 — see the long note beside the remote below for why an offline fixture
# cannot honestly reach rung 2, let alone the diff-page anchors of rung 1.
#
# The bug is a name collision. "Steward" means three separate things:
# `users.account_type` is an enum column, an accepted `InstituteRole` is a row in
# another table, and `chapters.steward_id` is a third. The push *into* /steward
# read the column; the guard *inside* /steward reads the role. Anyone holding the
# column without the role bounced between / and /steward forever.
#
# Planted, and none of it in the diff:
#   · application_controller.rb's two OTHER guards — require_profile_setup and
#     require_active_plan — still key on `steward?`. The fix narrowed one of
#     three, in a file whose changed lines sit forty lines above them.
#   · steward/base_controller.rb is the admission test the fix was aligned to,
#     and its require_steward_profile_setup is now dead for flag-only holders.
#   · matching/eligibility_filter.rb rejects on `steward?` twice, and
#     User.recommendable filters account_type in SQL for four jobs — so chapter
#     stewards silently enter the recommendation population.
#     general_recommendations_eligible excludes the free plan, which the same
#     diff now grants them, so the two scopes disagree about this population.
#   · user.rb's switch_to_free! comment names a controller guard the new caller
#     is not behind. The protection survives only because has_paid_subscription?
#     happens to require plan_active? — by conjunction, not by design.
#   · chapters_controller.rb skips require_active_plan but NOT
#     require_profile_setup, and `chapters` is absent from
#     profile_setup_not_required? — so the new redirect target bounces on to
#     profile setup exactly the users generate_steward_invite! selects for.
#   · load_management reads approved memberships and accept_steward_invite!
#     creates none, unlike add_leader! — the steward is missing from their own
#     roster.
#   · test/test_helper.rb completes every test user's profile on create, so a
#     green suite is consistent with that interception existing.
#   · accept_steward_invite! makes three writes with no transaction, where
#     ChaptersController#create wraps its two.
#   · scope :chapter_stewards has no callers anywhere.
# ---------------------------------------------------------------------------
F4=$DEST/monolith-guard-chain
mkdir -p "$F4"/app/models "$F4"/app/controllers/steward "$F4"/app/controllers/users \
         "$F4"/app/controllers/admin "$F4"/app/controllers/concerns \
         "$F4"/app/services/matching "$F4"/app/jobs/suggestions "$F4"/app/jobs/goals \
         "$F4"/app/jobs/action_items "$F4"/app/views/chapters \
         "$F4"/app/views/steward/dashboard \
         "$F4"/config "$F4"/db "$F4"/bin \
         "$F4"/test/controllers "$F4"/test/models "$F4"/test/fixtures
init_repo "$F4"

cat > "$F4/config/application.rb" <<'EOF'
require "rails/all"

module Commons
  class Application < Rails::Application
    config.load_defaults 8.1
  end
end
EOF
cat > "$F4/Gemfile" <<'EOF'
source "https://rubygems.org"

gem "rails", "~> 8.1"
gem "pg"
gem "puma"
gem "propshaft"
gem "turbo-rails"
gem "stimulus-rails"
gem "devise"
gem "flipper"
gem "flipper-active_record"

group :development, :test do
  gem "rubocop-rails-omakase", require: false
end
EOF

cat > "$F4/Gemfile.lock" <<'EOF'
GEM
  remote: https://rubygems.org/
  specs:
    activerecord (8.1.3.1)
    activesupport (8.1.3.1)
    devise (5.0.4)
    flipper (1.3.2)
    flipper-active_record (1.3.2)
    pg (1.5.9)
    propshaft (1.1.0)
    puma (6.5.0)
    rails (8.1.3.1)
    stimulus-rails (1.3.4)
    turbo-rails (2.0.11)

PLATFORMS
  ruby

DEPENDENCIES
  devise
  flipper
  flipper-active_record
  pg
  propshaft
  puma
  rails (~> 8.1)
  rubocop-rails-omakase
  stimulus-rails
  turbo-rails

BUNDLED WITH
   2.6.2
EOF
cat > "$F4/CLAUDE.md" <<'EOF'
# Commons

A Rails monolith. Members join **chapters**; a chapter may belong to an **institute**.
Server-rendered ERB plus Hotwire — there is no separate client package.

- Tests are Minitest: `bin/rails test`. Fixtures live in `test/fixtures/`.
- `bin/rubocop` (Rails Omakase) must pass before merge.
- Authorization is hand-written predicates on `User` and `Chapter`. No Pundit, no CanCan.
EOF
for b in rails setup rubocop dev; do
  printf '#!/usr/bin/env sh\nexec echo "stub: %s $*"\n' "$b" > "$F4/bin/$b"
  chmod +x "$F4/bin/$b"
done

cat > "$F4/config/routes.rb" <<'EOF'
Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  authenticated :user do
    root to: "dashboard#show", as: :authenticated_root
  end
  root to: "pages#home"

  resources :chapters, only: [ :index, :new, :create, :show, :update ] do
    member do
      get :manage
      post :join
      patch :set_role
    end
  end

  get "steward_invites/:token", to: "steward_invites#show", as: :steward_invite
  get "chapter_invites/:code", to: "chapter_invites#show", as: :chapter_invite

  get "memberships/select", to: "memberships#select", as: :select_plan
  post "memberships/activate_free", to: "memberships#activate_free", as: :activate_free_membership
  get "memberships", to: "memberships#show", as: :membership

  get "profile_setup/step/:step", to: "profile_setup#step", as: :step_profile_setup

  namespace :steward do
    root to: "dashboard#show"
    resource :profile_setup, only: [ :edit, :update ]
  end

  namespace :admin do
    root to: "dashboard#show"
    resources :institute_roles, only: [ :create, :destroy ]
  end
end
EOF

# ---- models -------------------------------------------------------------
cat > "$F4/app/models/user.rb" <<'EOF'
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Two legal values, enforced in Ruby only — db/schema.rb has no check
  # constraint on the column.
  enum :account_type, { member: 0, steward: 1 }, default: :member
  enum :plan, {
    community: 1,   # free, never expires
    circle: 0,      # keep 0 for rows that predate the enum
    everywhere: 2
  }, default: :circle

  # Tiers that go through paid checkout. Community is free and activated directly.
  PURCHASABLE_TIERS = %i[circle everywhere].freeze

  scope :non_admin, -> { where(admin: false) }
  scope :recommendable, -> { where(admin: false, account_type: :member) }
  scope :chapter_stewards, -> { where(chapter_steward: true) }
  # Free-plan members receive chapter-scoped suggestions only, never general ones.
  scope :general_recommendations_eligible, -> { recommendable.where.not(plan: :community) }

  has_one :profile, dependent: :destroy
  has_many :institute_roles, dependent: :destroy
  has_many :institutes, through: :institute_roles
  has_many :chapter_memberships, dependent: :destroy
  has_many :chapters, through: :chapter_memberships
  has_many :stewarded_chapters, class_name: "Chapter", foreign_key: :steward_id,
           inverse_of: :steward, dependent: :nullify

  validates :email, presence: true

  after_create :build_default_profile

  def display_name
    profile&.first_name.presence || email.split("@").first
  end

  def plan_active?
    return true if community? # free tier, never expires
    return false if plan_expires_at.nil?

    plan_expires_at > Time.current
  end

  def activate_plan!(tier: nil)
    attrs = { in_trial: false, plan_started_at: Time.current, plan_expires_at: 1.year.from_now }
    attrs[:plan] = tier if tier.present?
    update!(attrs)
  end

  # Downgrade to the free Community tier. Ends any active trial and clears the
  # expiry (the free tier never expires). Safe only for non-paying users; the
  # controller guards genuine Stripe subscribers out of this path.
  def switch_to_free!
    update!(
      plan: :community,
      in_trial: false,
      plan_expires_at: nil
    )
  end

  def has_paid_subscription?
    stripe_customer_id.present? && plan_active? && !in_trial?
  end

  def trial_active?
    in_trial? && plan_expires_at.present? && plan_expires_at > Time.current
  end

  # Institute stewardship. This is the fact the /steward section admits on, and
  # it is a row in another table — not the account_type column.
  def steward_for_any_institute?
    institute_roles.accepted.exists?
  end

  def institute_steward?(institute)
    institute_roles.exists?(institute: institute)
  end

  def institute_owner?(institute)
    institute_roles.accepted.exists?(institute: institute, owner: true)
  end

  def current_institute
    institutes.merge(InstituteRole.accepted).first
  end

  # Every chapter this user is visible in. Reads memberships, not stewardship.
  def chapters_list
    chapter_memberships.approved.includes(:chapter).map(&:chapter)
  end

  private

  def build_default_profile
    create_profile! unless profile.present?
  end
end
EOF
cat > "$F4/app/models/institute_role.rb" <<'EOF'
class InstituteRole < ApplicationRecord
  belongs_to :user
  belongs_to :institute

  scope :accepted, -> { where.not(accepted_at: nil) }

  # Accepting the invitation is what makes someone an institute steward. The
  # account_type column is written alongside it, for the section's own profile
  # guard; the admission test itself only ever reads this row.
  def accept!
    transaction do
      update!(accepted_at: Time.current)
      user.update!(account_type: :steward) unless user.steward?
    end
  end
end
EOF
cat > "$F4/app/models/institute.rb" <<'EOF'
class Institute < ApplicationRecord
  has_many :institute_roles, dependent: :destroy
  has_many :users, through: :institute_roles
  has_many :chapters, dependent: :nullify

  validates :name, presence: true
end
EOF
cat > "$F4/app/models/chapter_membership.rb" <<'EOF'
class ChapterMembership < ApplicationRecord
  belongs_to :user
  belongs_to :chapter

  enum :role, { member: 0, leader: 1 }, default: :member
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :approved
end
EOF
cat > "$F4/app/models/profile.rb" <<'EOF'
class Profile < ApplicationRecord
  belongs_to :user

  def setup_completed?
    setup_completed_at.present?
  end

  def complete?
    setup_completed? && first_name.present? && last_name.present?
  end
end
EOF
cat > "$F4/app/models/chapter.rb" <<'EOF'
class Chapter < ApplicationRecord
  has_many :chapter_memberships, dependent: :destroy
  has_many :users, through: :chapter_memberships
  belongs_to :institute, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  # A chapter has at most one steward. Nothing makes the reverse side unique:
  # one user may steward many chapters. See db/schema.rb.
  belongs_to :steward, class_name: "User", optional: true, inverse_of: :stewarded_chapters

  # open: anyone browsing can self-serve join. closed: joining creates a pending
  # request a leader approves. Prefixed to read clearly (join_open?).
  enum :join_policy, { open: 0, closed: 1 }, default: :open, prefix: :join

  validates :name, presence: true

  scope :discoverable, -> { where(discoverable: true, active: true) }

  # An institute-less hub a member runs themselves.
  def self.build_member_hub(attrs, owner:)
    new(attrs).tap do |chapter|
      chapter.created_by = owner
      chapter.active = true
      chapter.discoverable = true
    end
  end

  # Makes the given user an approved leader of this chapter (used when a member
  # creates their own chapter, so they land on the manage surface as a member of it).
  def add_leader!(user)
    chapter_memberships.create!(
      user: user, role: :leader, status: :approved, joined_at: Time.current
    )
  end

  def add_member!(user, role: :member)
    chapter_memberships.create!(
      user: user, role: role, status: :approved, joined_at: Time.current
    )
  end

  # A closed-chapter join request — pending until a leader decides.
  def request_membership!(user)
    chapter_memberships.create!(
      user: user, role: :member, status: :pending, joined_at: Time.current
    )
  end

  # Pending join requests awaiting a decision (for the manage UI).
  def pending_requests
    chapter_memberships.pending.includes(user: :profile).order(:joined_at)
  end

  def leader?(user)
    chapter_memberships.approved.exists?(user: user, role: :leader)
  end

  # Chapter leadership: leaders, the steward, and (for institute-backed chapters)
  # the institute's owners run the chapter — approve requests, manage members,
  # edit settings. Regular members cannot. Broader than #can_manage? in that it
  # also includes chapter leaders.
  def can_lead?(user)
    return false unless user

    leader?(user) || can_manage?(user)
  end

  # Approving and rejecting pending join requests is a leadership action.
  def can_moderate_requests?(user)
    can_lead?(user)
  end

  # Who can manage this chapter: a platform admin, the chapter's steward, or an
  # institute owner. The steward branch reads the column on chapters, so it
  # passes with no ChapterMembership at all.
  def can_manage?(user)
    return false unless user
    return true if user.admin?
    return true if steward_id == user.id

    institute.present? && user.institute_owner?(institute)
  end

  def approve_request!(membership)
    membership.approved!
  end

  # Invites are aimed at people who are not already settled members: an existing
  # member with a finished profile is told to be added as a leader instead.
  def generate_steward_invite!(email)
    existing_user = User.find_by(email: email.downcase)
    if existing_user&.member? && existing_user.profile&.setup_completed?
      raise ArgumentError, "Cannot invite an existing member as steward"
    end

    self.steward_invite_token = SecureRandom.urlsafe_base64(32)
    self.steward_invite_email = email.downcase
    save!
  end

  def accept_steward_invite!(user)
    raise ArgumentError, "Email mismatch" unless user.email.downcase == steward_invite_email&.downcase

    user.update!(chapter_steward: true) unless user.chapter_steward?
    user.update!(account_type: :steward) unless user.steward?
    self.steward = user
    self.steward_invite_token = nil
    self.steward_invite_email = nil
    save!
  end

  def pending_steward_invite?
    steward_invite_token.present?
  end
end
EOF

# ---- controllers --------------------------------------------------------
cat > "$F4/app/controllers/application_controller.rb" <<'EOF'
class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale
  before_action :redirect_admin_to_admin_section
  before_action :redirect_steward_to_steward_section
  before_action :require_profile_setup
  before_action :require_active_plan

  protected

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def after_sign_in_path_for(resource)
    return admin_root_path if resource.admin?

    authenticated_root_path
  end

  def redirect_admin_to_admin_section
    return unless user_signed_in?
    return unless current_user.admin?
    return if admin_controller?
    return if auth_controller?

    redirect_to admin_root_path
  end

  def admin_controller?
    self.class.module_parent_name == "Admin"
  end

  def auth_controller?
    controller_name.in?(%w[sessions registrations passwords confirmations unlocks])
  end

  def redirect_steward_to_steward_section
    return unless user_signed_in?
    return if current_user.admin?
    return unless current_user.steward? || current_user.steward_for_any_institute?
    return if steward_controller?
    return if steward_accessible_controller?

    redirect_to steward_root_path
  end

  def steward_controller?
    self.class.module_parent_name == "Steward"
  end

  # The allowlist is why the invite page itself stays reachable while a user is
  # otherwise bouncing.
  def steward_accessible_controller?
    controller_name.in?(%w[sessions registrations passwords confirmations unlocks
                           steward_invites chapter_invites locales])
  end

  def require_active_plan
    return unless user_signed_in?
    return if current_user.admin?
    return if current_user.steward?
    return if current_user.steward_for_any_institute?
    return if plan_not_required?
    return if current_user.plan_active?

    redirect_to select_plan_path, alert: t("flash.authorization.plan_required")
  end

  def plan_not_required?
    controller_name.in?(%w[sessions registrations passwords memberships profile_setup
                           chapters chapter_invites steward_invites])
  end

  def require_profile_setup
    return unless user_signed_in?
    return if current_user.admin?
    return if current_user.steward?
    return if current_user.steward_for_any_institute?
    return if profile_setup_not_required?
    return if current_user.profile&.setup_completed?

    redirect_to step_profile_setup_path(step: current_user.profile&.setup_step || 1),
                alert: t("flash.authorization.profile_setup_required")
  end

  # Note what is absent here: `chapters`. The plan guard above exempts it; this
  # one does not.
  def profile_setup_not_required?
    controller_name.in?(%w[sessions registrations passwords memberships profile_setup
                           chapter_invites steward_invites])
  end
end
EOF
cat > "$F4/app/controllers/steward/base_controller.rb" <<'EOF'
class Steward::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_steward!
  before_action :require_steward_profile_setup

  skip_before_action :redirect_steward_to_steward_section
  skip_before_action :require_active_plan
  skip_before_action :require_profile_setup

  layout "steward"

  helper_method :current_institute

  private

  # The one admission test for this whole section, and it reads the role row.
  # users.account_type is not consulted here, and never has been.
  def authorize_steward!
    unless current_user.steward_for_any_institute?
      redirect_to authenticated_root_path, alert: t("flash.authorization.steward_required")
    end
  end

  def require_steward_profile_setup
    return unless current_user.steward?
    return if current_user.profile&.setup_completed?

    redirect_to edit_steward_profile_setup_path
  end

  def current_institute
    @current_institute ||= current_user.current_institute
  end
end
EOF
cat > "$F4/app/controllers/steward/dashboard_controller.rb" <<'EOF'
class Steward::DashboardController < Steward::BaseController
  def show
    @chapters = current_institute&.chapters&.order(:name) || Chapter.none
  end
end
EOF
cat > "$F4/app/controllers/concerns/requires_chapter_hubs_flag.rb" <<'EOF'
module RequiresChapterHubsFlag
  extend ActiveSupport::Concern

  private

  def require_chapter_hubs_flag!
    return if Flipper.enabled?(:chapter_hubs, current_user)

    redirect_to authenticated_root_path, alert: t("flash.authorization.not_available")
  end
end
EOF
cat > "$F4/app/controllers/chapters_controller.rb" <<'EOF'
class ChaptersController < ApplicationController
  include RequiresChapterHubsFlag

  skip_before_action :require_active_plan
  skip_before_action :redirect_admin_to_admin_section

  before_action :authenticate_user!
  # The directory and self-serve join are the new hub surfaces — flag-gated. The
  # member chapter page (show) stays open to existing institute-chapter members.
  before_action :require_chapter_hubs_flag!, only: [ :index, :new, :create, :join ]
  before_action :set_chapter, only: [ :show, :join, :manage, :update, :set_role ]
  before_action :require_membership!, only: [ :show, :set_role ]
  before_action :authorize_leader!, only: [ :manage, :update ]

  # Public directory of free, discoverable chapter hubs.
  def index
    @chapters = Chapter.discoverable.order(:name)
    @my_chapter_ids = current_user.chapter_memberships.approved.pluck(:chapter_id).to_set
  end

  # Self-service: a member brings their own chapter onto Commons for free.
  def new
    @chapter = Chapter.new(join_policy: :open)
  end

  def create
    @chapter = Chapter.build_member_hub(chapter_params, owner: current_user)

    ActiveRecord::Base.transaction do
      @chapter.save!
      @chapter.add_leader!(current_user)
    end

    redirect_to manage_chapter_path(@chapter), notice: t("chapters.new.created")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @memberships = @chapter.chapter_memberships.approved.includes(user: :profile)
  end

  def manage
    load_management
  end

  def update
    if @chapter.update(chapter_settings_params)
      redirect_to manage_chapter_path(@chapter), notice: t("chapters.manage.updated")
    else
      load_management
      render :manage, status: :unprocessable_entity
    end
  end

  def join
    if @chapter.join_open?
      @chapter.add_member!(current_user)
      redirect_to chapter_path(@chapter), notice: t("chapters.join.joined")
    else
      @chapter.request_membership!(current_user)
      redirect_to chapters_path, notice: t("chapters.join.requested")
    end
  end

  def set_role
    membership = @chapter.chapter_memberships.find_by!(user_id: params[:user_id])
    membership.update!(role: params[:role])
    redirect_to manage_chapter_path(@chapter)
  end

  private

  def set_chapter
    @chapter = Chapter.find(params[:id])
  end

  def require_membership!
    return if @chapter.chapter_memberships.approved.exists?(user: current_user)
    return if @chapter.can_manage?(current_user)

    redirect_to chapters_path, alert: t("chapters.show.not_a_member")
  end

  # Data for the leader management surface. Reads approved memberships, so a
  # steward who holds no membership does not appear in their own roster.
  def load_management
    @pending_requests = @chapter.pending_requests
    @memberships = @chapter.chapter_memberships.approved
                           .includes(user: :profile).order(role: :desc, created_at: :asc)
    @member_count = @memberships.size
  end

  def authorize_leader!
    return if @chapter&.can_lead?(current_user)

    redirect_to chapter_path(@chapter), alert: t("chapters.manage.not_a_leader")
  end

  def chapter_params
    params.require(:chapter).permit(:name, :description, :join_policy)
  end

  def chapter_settings_params
    params.require(:chapter).permit(:description, :join_policy)
  end
end
EOF
cat > "$F4/app/controllers/steward_invites_controller.rb" <<'EOF'
class StewardInvitesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chapter

  def show
    unless current_user.email.downcase == @chapter.steward_invite_email&.downcase
      redirect_to authenticated_root_path, alert: t(".email_mismatch")
      return
    end

    @chapter.accept_steward_invite!(current_user)
    redirect_to steward_root_path, notice: t(".success", chapter_name: @chapter.name)
  end

  private

  # The token is cleared on acceptance, so a second visit to the same URL lands
  # here rather than accepting twice.
  def set_chapter
    @chapter = Chapter.find_by(steward_invite_token: params[:token])
    return if @chapter

    redirect_to authenticated_root_path, alert: t(".invalid_token")
  end
end
EOF
cat > "$F4/app/controllers/users/registrations_controller.rb" <<'EOF'
class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      process_pending_steward_invite(resource) if resource.persisted?
    end
  end

  protected

  # Runs inside Devise's create block, before after_sign_up_path_for is called.
  # This is what assigns chapters.steward_id for a brand-new account.
  def process_pending_steward_invite(resource)
    token = session.delete(:pending_steward_invite_token)
    return if token.blank?

    chapter = Chapter.find_by(steward_invite_token: token)
    return if chapter.nil?
    return unless chapter.steward_invite_email&.downcase == resource.email.downcase

    chapter.accept_steward_invite!(resource)
  end

  def after_sign_up_path_for(resource)
    return steward_root_path if resource.steward?
    return steward_root_path if resource.chapter_steward?
    return steward_root_path if resource.steward_for_any_institute?

    # Profile setup first, then payment
    step_profile_setup_path(step: 1)
  end
end
EOF
cat > "$F4/app/controllers/memberships_controller.rb" <<'EOF'
class MembershipsController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  def select
  end

  # The guard switch_to_free!'s own comment refers to. A genuine paying
  # subscriber is sent to the billing portal instead of being downgraded.
  def activate_free
    if current_user.has_paid_subscription?
      redirect_to membership_path, alert: t(".cancel_subscription_first")
      return
    end

    current_user.switch_to_free!
    redirect_to authenticated_root_path, notice: t(".activated")
  end
end
EOF
cat > "$F4/app/controllers/admin/institute_roles_controller.rb" <<'EOF'
class Admin::InstituteRolesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def create
    user = User.find(params[:user_id])
    institute = Institute.find(params[:institute_id])

    InstituteRole.create!(user: user, institute: institute, accepted_at: Time.current)
    user.update!(account_type: :steward) unless user.steward?

    redirect_to admin_root_path, notice: "#{user.email} now stewards #{institute.name}"
  end

  def destroy
    InstituteRole.find(params[:id]).destroy!
    redirect_to admin_root_path
  end

  private

  def require_admin!
    redirect_to authenticated_root_path unless current_user.admin?
  end
end
EOF

# ---- service and jobs ---------------------------------------------------
cat > "$F4/app/services/matching/eligibility_filter.rb" <<'EOF'
module Matching
  # Decides who may appear in a recommendation, and which pairs may be scored.
  class EligibilityFilter
    def initialize(options = {})
      @options = options
    end

    def eligible_users(users)
      filter_users(users)
    end

    # Check whether two specific users may be scored against each other.
    def eligible_pair?(user_a, user_b)
      return false if user_a.id == user_b.id
      return false if user_a.admin? || user_b.admin?
      return false if user_a.steward? || user_b.steward?
      return false if user_a.recommendations_paused? || user_b.recommendations_paused?
      return false if @options[:require_complete_profile] && !profiles_complete?(user_a, user_b)
      return false if @options[:exclude_same_company] && same_company?(user_a, user_b)

      true
    end

    def eligible_pair_count(users)
      n = filter_users(users).size
      n * (n - 1) / 2
    end

    private

    def filter_users(users)
      filtered = users.respond_to?(:includes) ? users.includes(:profile).to_a : users.to_a

      # Always exclude admin and steward users from recommendations
      filtered = filtered.reject { |u| u.admin? || u.steward? }

      if @options[:require_complete_profile]
        filtered = filtered.select { |u| u.profile&.complete? }
      end

      filtered
    end

    def profiles_complete?(user_a, user_b)
      user_a.profile&.complete? && user_b.profile&.complete?
    end

    def same_company?(user_a, user_b)
      user_a.profile&.company.present? && user_a.profile.company == user_b.profile&.company
    end
  end
end
EOF
cat > "$F4/app/jobs/suggestions/generate_weekly_job.rb" <<'EOF'
module Suggestions
  class GenerateWeeklyJob < ApplicationJob
    queue_as :default

    def perform
      User.general_recommendations_eligible.find_each do |user|
        Suggestions::Builder.new(user).call
      end
    end
  end
end
EOF
cat > "$F4/app/jobs/suggestions/generate_teams_job.rb" <<'EOF'
module Suggestions
  class GenerateTeamsJob < ApplicationJob
    queue_as :default

    def perform(chapter_id)
      chapter = Chapter.find(chapter_id)
      candidates = chapter.users.merge(User.recommendable)
      Matching::EligibilityFilter.new(require_complete_profile: true).eligible_users(candidates)
    end
  end
end
EOF
cat > "$F4/app/jobs/goals/send_reminder_notifications_job.rb" <<'EOF'
module Goals
  class SendReminderNotificationsJob < ApplicationJob
    queue_as :default

    def perform
      User.recommendable.where(recommendations_paused: false).find_each do |user|
        GoalMailer.weekly_reminder(user).deliver_later
      end
    end
  end
end
EOF
cat > "$F4/app/jobs/action_items/generate_all_job.rb" <<'EOF'
module ActionItems
  class GenerateAllJob < ApplicationJob
    queue_as :default

    def perform
      User.recommendable.find_each { |user| ActionItems::Builder.new(user).call }
    end
  end
end
EOF

# ---- views --------------------------------------------------------------
cat > "$F4/app/views/chapters/manage.html.erb" <<'EOF'
<h1><%= @chapter.name %></h1>

<section>
  <h2><%= t(".members", count: @member_count) %></h2>
  <ul>
    <% @memberships.each do |membership| %>
      <li><%= membership.user.display_name %> &mdash; <%= membership.role %></li>
    <% end %>
  </ul>
</section>

<section>
  <h2><%= t(".pending") %></h2>
  <% @pending_requests.each do |request| %>
    <%= button_to t(".approve"),
          set_role_chapter_path(@chapter, user_id: request.user_id, role: :member) %>
  <% end %>
</section>
EOF
cat > "$F4/app/views/steward/dashboard/show.html.erb" <<'EOF'
<h1><%= t(".title", institute: current_institute&.name) %></h1>

<ul>
  <% @chapters.each do |chapter| %>
    <li><%= link_to chapter.name, manage_chapter_path(chapter) %></li>
  <% end %>
</ul>
EOF

# ---- schema -------------------------------------------------------------
cat > "$F4/db/schema.rb" <<'EOF'
ActiveRecord::Schema[8.1].define(version: 2026_08_01_000000) do
  create_table "chapter_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "chapter_id", null: false
    t.integer "role", default: 0, null: false
    t.integer "status", default: 1, null: false
    t.datetime "joined_at"
    t.timestamps
    t.index [ "chapter_id", "user_id" ], name: "index_chapter_memberships_on_chapter_and_user", unique: true
  end

  create_table "chapters", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "join_policy", default: 0, null: false
    t.boolean "discoverable", default: false, null: false
    t.boolean "active", default: true, null: false
    t.bigint "institute_id"
    t.bigint "created_by_id"
    t.bigint "steward_id"
    t.string "steward_invite_token"
    t.string "steward_invite_email"
    t.string "invite_code"
    t.timestamps
    # Not unique: one user may steward many chapters, so find_by(steward_id:)
    # has no defined ordering.
    t.index [ "steward_id" ], name: "index_chapters_on_steward_id"
    t.index [ "steward_invite_token" ], name: "index_chapters_on_steward_invite_token", unique: true
    t.index [ "invite_code" ], name: "index_chapters_on_invite_code", unique: true
  end

  create_table "institute_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "institute_id", null: false
    t.boolean "owner", default: false, null: false
    t.datetime "accepted_at"
    t.timestamps
    t.index [ "user_id", "institute_id" ], name: "index_institute_roles_on_user_and_institute", unique: true
  end

  create_table "institutes", force: :cascade do |t|
    t.string "name", null: false
    t.timestamps
  end

  create_table "profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "job_title"
    t.string "company"
    t.integer "setup_step", default: 1, null: false
    t.datetime "setup_completed_at"
    t.timestamps
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "admin", default: false, null: false
    # No check constraint: the enum's two values are a Ruby-side rule only.
    t.integer "account_type", default: 0, null: false
    t.boolean "chapter_steward", default: false, null: false
    t.integer "plan", default: 0, null: false
    t.datetime "plan_started_at"
    t.datetime "plan_expires_at"
    t.boolean "in_trial", default: false, null: false
    t.string "stripe_customer_id"
    t.boolean "recommendations_paused", default: false, null: false
    t.timestamps
    t.index [ "email" ], name: "index_users_on_email", unique: true
  end

  add_foreign_key "chapter_memberships", "chapters"
  add_foreign_key "chapter_memberships", "users"
  add_foreign_key "chapters", "institutes"
  add_foreign_key "chapters", "users", column: "created_by_id"
  add_foreign_key "chapters", "users", column: "steward_id"
  add_foreign_key "institute_roles", "institutes"
  add_foreign_key "institute_roles", "users"
  add_foreign_key "profiles", "users"
end
EOF

# ---- test harness -------------------------------------------------------
cat > "$F4/test/test_helper.rb" <<'EOF'
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Auto-complete profile setup for users created in tests.
# This keeps tests from failing on the profile setup guard.
User.class_eval do
  after_create :auto_complete_profile_for_test

  def auto_complete_profile_for_test
    return unless Rails.env.test?
    return unless profile.present?
    return if profile.setup_completed?

    profile.update_columns(
      first_name: profile.first_name || "Test",
      last_name: profile.last_name || "User",
      job_title: profile.job_title || "Engineer",
      company: profile.company || "Test Co",
      setup_step: 5,
      setup_completed_at: Time.current
    )
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def create_user_with_plan(attrs = {})
    user = User.create!({ email: "user#{SecureRandom.hex(4)}@example.com",
                          password: "password123" }.merge(attrs))
    user.activate_plan!
    user
  end
end
EOF
cat > "$F4/test/fixtures/users.yml" <<'EOF'
member:
  email: member@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>
  account_type: 0
  plan: 1

institute_steward:
  email: institute-steward@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>
  account_type: 1
  plan: 1

bob:
  email: bob@test.com
  encrypted_password: <%= Devise::Encryptor.digest(User, "password123") %>
  account_type: 0
  plan: 0
EOF
cat > "$F4/test/fixtures/institutes.yml" <<'EOF'
tech:
  name: Tech Institute
EOF
cat > "$F4/test/fixtures/institute_roles.yml" <<'EOF'
# The only accepted role in the fixtures: users(:institute_steward) is the one
# user for whom steward_for_any_institute? is true.
steward_owns_tech:
  user: institute_steward
  institute: tech
  owner: true
  accepted_at: <%= 1.month.ago %>
EOF
cat > "$F4/test/fixtures/chapters.yml" <<'EOF'
downtown:
  name: Downtown Chapter
  description: A chapter used by the invite tests
  join_policy: 1
  discoverable: true
  active: true
EOF
cat > "$F4/test/models/chapter_test.rb" <<'EOF'
require "test_helper"

class ChapterTest < ActiveSupport::TestCase
  setup do
    @chapter = chapters(:downtown)
  end

  test "generate_steward_invite! stores a token and the invited email" do
    @chapter.generate_steward_invite!("New.Steward@example.com")

    assert @chapter.pending_steward_invite?
    assert_equal "new.steward@example.com", @chapter.steward_invite_email
  end

  test "generate_steward_invite! refuses a settled member" do
    settled = User.create!(email: "settled@example.com", password: "password123")
    settled.profile.update!(setup_completed_at: Time.current)

    assert_raises(ArgumentError) { @chapter.generate_steward_invite!(settled.email) }
  end

  test "accept_steward_invite! makes the user the chapter steward" do
    invite_email = "steward.#{SecureRandom.hex(4)}@example.com"
    @chapter.generate_steward_invite!(invite_email)

    new_user = User.create!(email: invite_email, password: "password123")

    @chapter.accept_steward_invite!(new_user)

    assert new_user.reload.chapter_steward?
    assert new_user.steward?
    assert_equal new_user, @chapter.reload.steward
    assert_nil @chapter.steward_invite_token
    assert_nil @chapter.steward_invite_email
  end

  test "accept_steward_invite! raises on email mismatch" do
    @chapter.generate_steward_invite!("someone.else@example.com")
    other = User.create!(email: "wrong.person@example.com", password: "password123")

    assert_raises(ArgumentError) { @chapter.accept_steward_invite!(other) }
  end

  test "can_manage? accepts the steward with no membership" do
    user = User.create!(email: "steward.only@example.com", password: "password123")
    @chapter.update!(steward: user)

    assert @chapter.can_manage?(user)
    assert_empty @chapter.chapter_memberships.approved.where(user: user)
  end
end
EOF
cat > "$F4/test/controllers/steward_invites_controller_test.rb" <<'EOF'
require "test_helper"

class StewardInvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chapter = chapters(:downtown)
    @bob = users(:bob)
    @chapter.update!(steward_invite_token: "test-invite-token-123",
                     steward_invite_email: @bob.email)
    sign_in @bob
  end

  test "accepting the invite makes bob the chapter steward" do
    get steward_invite_path(token: "test-invite-token-123")

    assert_redirected_to steward_root_path
    assert @bob.reload.chapter_steward?
    assert_equal @bob, @chapter.reload.steward
    assert_nil @chapter.steward_invite_token
    assert_nil @chapter.steward_invite_email
  end

  test "a mismatched email is turned away" do
    sign_in users(:member)

    get steward_invite_path(token: "test-invite-token-123")

    assert_redirected_to authenticated_root_path
    assert_not users(:member).reload.chapter_steward?
  end

  test "an unknown token is turned away" do
    get steward_invite_path(token: "no-such-token")

    assert_redirected_to authenticated_root_path
  end
end
EOF

# ---- the rest of the app ------------------------------------------------
# Thin, but present. The first live run against this fixture reported the
# checkout as partial — ApplicationRecord and ApplicationJob were missing, and so
# were the classes the code under review names. Two reasons that matters more
# than tidiness. A run cannot tell an accidental gap from a planted one, so an
# unintended defect competes for the attention the planted findings are meant to
# get. And one of those gaps undercut the fixture's central Flow C finding: the
# claim is that a chapter steward is redirected on to `step_profile_setup_path`,
# which is weaker if the controller behind that path does not exist.
mkdir -p "$F4"/app/mailers "$F4"/app/services/action_items "$F4"/app/services/suggestions \
         "$F4"/app/views/dashboard "$F4"/app/views/pages
cat > "$F4/app/models/application_record.rb" <<'EOF'
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
EOF
cat > "$F4/app/jobs/application_job.rb" <<'EOF'
class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked
  discard_on ActiveJob::DeserializationError
end
EOF
cat > "$F4/app/mailers/application_mailer.rb" <<'EOF'
class ApplicationMailer < ActionMailer::Base
  default from: "hello@commons.example"
  layout "mailer"
end
EOF
cat > "$F4/app/mailers/goal_mailer.rb" <<'EOF'
class GoalMailer < ApplicationMailer
  def weekly_reminder(user)
    @user = user
    mail(to: @user.email, subject: t("goal_mailer.weekly_reminder.subject"))
  end
end
EOF
cat > "$F4/app/services/action_items/builder.rb" <<'EOF'
module ActionItems
  class Builder
    def initialize(user)
      @user = user
    end

    def call
      # Placeholder for the generation this fixture does not exercise.
      @user.chapters_list
    end
  end
end
EOF
cat > "$F4/app/services/suggestions/builder.rb" <<'EOF'
module Suggestions
  class Builder
    def initialize(user)
      @user = user
    end

    def call
      Matching::EligibilityFilter.new(require_complete_profile: true)
                                 .eligible_users(User.recommendable.where.not(id: @user.id))
    end
  end
end
EOF
cat > "$F4/app/controllers/dashboard_controller.rb" <<'EOF'
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @chapters = current_user.chapters_list
  end
end
EOF
cat > "$F4/app/controllers/pages_controller.rb" <<'EOF'
class PagesController < ApplicationController
  skip_before_action :require_profile_setup
  skip_before_action :require_active_plan

  def home
  end
end
EOF
# The destination require_profile_setup sends people to. Exempt from the guard
# itself via profile_setup_not_required?, or it would redirect to itself.
cat > "$F4/app/controllers/profile_setup_controller.rb" <<'EOF'
class ProfileSetupController < ApplicationController
  before_action :authenticate_user!

  STEPS = 5

  def step
    @step = params[:step].to_i.clamp(1, STEPS)
    @profile = current_user.profile
  end

  def update
    @profile = current_user.profile
    @profile.update!(profile_params)
    if @profile.setup_step >= STEPS
      @profile.update!(setup_completed_at: Time.current)
      redirect_to authenticated_root_path, notice: t(".done")
    else
      redirect_to step_profile_setup_path(step: @profile.setup_step + 1)
    end
  end

  private

  def profile_params
    params.require(:profile).permit(:first_name, :last_name, :job_title, :company, :setup_step)
  end
end
EOF
cat > "$F4/app/controllers/chapter_invites_controller.rb" <<'EOF'
class ChapterInvitesController < ApplicationController
  before_action :authenticate_user!

  # Ordinary member invites, by code. Unrelated to steward invites, and named in
  # both guard allowlists.
  def show
    @chapter = Chapter.find_by(invite_code: params[:code])
    return redirect_to authenticated_root_path, alert: t(".invalid_code") if @chapter.nil?

    @chapter.add_member!(current_user) unless @chapter.chapter_memberships.exists?(user: current_user)
    redirect_to chapter_path(@chapter), notice: t(".joined")
  end
end
EOF
cat > "$F4/app/controllers/admin/dashboard_controller.rb" <<'EOF'
class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    @pending_roles = InstituteRole.where(accepted_at: nil)
  end

  private

  def require_admin!
    redirect_to authenticated_root_path unless current_user.admin?
  end
end
EOF
cat > "$F4/app/controllers/steward/profile_setups_controller.rb" <<'EOF'
class Steward::ProfileSetupsController < Steward::BaseController
  skip_before_action :require_steward_profile_setup

  def edit
    @profile = current_user.profile
  end

  def update
    current_user.profile.update!(setup_completed_at: Time.current)
    redirect_to steward_root_path
  end
end
EOF
cat > "$F4/app/views/dashboard/show.html.erb" <<'EOF'
<h1><%= t(".greeting", name: current_user.display_name) %></h1>

<ul>
  <% @chapters.each do |chapter| %>
    <li><%= link_to chapter.name, chapter_path(chapter) %></li>
  <% end %>
</ul>
EOF
cat > "$F4/app/views/pages/home.html.erb" <<'EOF'
<h1><%= t(".headline") %></h1>
<p><%= link_to t(".sign_up"), new_user_registration_path %></p>
EOF
commit "$F4" "base"

# ---- the change ---------------------------------------------------------
# Four production lines. The two large files are rewritten whole, as F1 and F2
# rewrite theirs; the summary at the end of this script prints each fixture's
# changed paths, so a head copy that drifts back into agreement with its base
# drops out of that list rather than failing silently.
cat > "$F4/app/controllers/application_controller.rb" <<'EOF'
class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale
  before_action :redirect_admin_to_admin_section
  before_action :redirect_steward_to_steward_section
  before_action :require_profile_setup
  before_action :require_active_plan

  protected

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def after_sign_in_path_for(resource)
    return admin_root_path if resource.admin?

    authenticated_root_path
  end

  def redirect_admin_to_admin_section
    return unless user_signed_in?
    return unless current_user.admin?
    return if admin_controller?
    return if auth_controller?

    redirect_to admin_root_path
  end

  def admin_controller?
    self.class.module_parent_name == "Admin"
  end

  def auth_controller?
    controller_name.in?(%w[sessions registrations passwords confirmations unlocks])
  end

  # Only send people to /steward when they can actually get in. The section
  # admits users with an accepted institute role (Steward::BaseController), so
  # redirecting on account_type alone bounced anyone carrying that flag without
  # a role between / and /steward forever.
  def redirect_steward_to_steward_section
    return unless user_signed_in?
    return if current_user.admin?
    return unless current_user.steward_for_any_institute?
    return if steward_controller?
    return if steward_accessible_controller?

    redirect_to steward_root_path
  end

  def steward_controller?
    self.class.module_parent_name == "Steward"
  end

  # The allowlist is why the invite page itself stays reachable while a user is
  # otherwise bouncing.
  def steward_accessible_controller?
    controller_name.in?(%w[sessions registrations passwords confirmations unlocks
                           steward_invites chapter_invites locales])
  end

  def require_active_plan
    return unless user_signed_in?
    return if current_user.admin?
    return if current_user.steward?
    return if current_user.steward_for_any_institute?
    return if plan_not_required?
    return if current_user.plan_active?

    redirect_to select_plan_path, alert: t("flash.authorization.plan_required")
  end

  def plan_not_required?
    controller_name.in?(%w[sessions registrations passwords memberships profile_setup
                           chapters chapter_invites steward_invites])
  end

  def require_profile_setup
    return unless user_signed_in?
    return if current_user.admin?
    return if current_user.steward?
    return if current_user.steward_for_any_institute?
    return if profile_setup_not_required?
    return if current_user.profile&.setup_completed?

    redirect_to step_profile_setup_path(step: current_user.profile&.setup_step || 1),
                alert: t("flash.authorization.profile_setup_required")
  end

  # Note what is absent here: `chapters`. The plan guard above exempts it; this
  # one does not.
  def profile_setup_not_required?
    controller_name.in?(%w[sessions registrations passwords memberships profile_setup
                           chapter_invites steward_invites])
  end
end
EOF
cat > "$F4/app/models/chapter.rb" <<'EOF'
class Chapter < ApplicationRecord
  has_many :chapter_memberships, dependent: :destroy
  has_many :users, through: :chapter_memberships
  belongs_to :institute, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  # A chapter has at most one steward. Nothing makes the reverse side unique:
  # one user may steward many chapters. See db/schema.rb.
  belongs_to :steward, class_name: "User", optional: true, inverse_of: :stewarded_chapters

  # open: anyone browsing can self-serve join. closed: joining creates a pending
  # request a leader approves. Prefixed to read clearly (join_open?).
  enum :join_policy, { open: 0, closed: 1 }, default: :open, prefix: :join

  validates :name, presence: true

  scope :discoverable, -> { where(discoverable: true, active: true) }

  # An institute-less hub a member runs themselves.
  def self.build_member_hub(attrs, owner:)
    new(attrs).tap do |chapter|
      chapter.created_by = owner
      chapter.active = true
      chapter.discoverable = true
    end
  end

  # Makes the given user an approved leader of this chapter (used when a member
  # creates their own chapter, so they land on the manage surface as a member of it).
  def add_leader!(user)
    chapter_memberships.create!(
      user: user, role: :leader, status: :approved, joined_at: Time.current
    )
  end

  def add_member!(user, role: :member)
    chapter_memberships.create!(
      user: user, role: role, status: :approved, joined_at: Time.current
    )
  end

  # A closed-chapter join request — pending until a leader decides.
  def request_membership!(user)
    chapter_memberships.create!(
      user: user, role: :member, status: :pending, joined_at: Time.current
    )
  end

  # Pending join requests awaiting a decision (for the manage UI).
  def pending_requests
    chapter_memberships.pending.includes(user: :profile).order(:joined_at)
  end

  def leader?(user)
    chapter_memberships.approved.exists?(user: user, role: :leader)
  end

  # Chapter leadership: leaders, the steward, and (for institute-backed chapters)
  # the institute's owners run the chapter — approve requests, manage members,
  # edit settings. Regular members cannot. Broader than #can_manage? in that it
  # also includes chapter leaders.
  def can_lead?(user)
    return false unless user

    leader?(user) || can_manage?(user)
  end

  # Approving and rejecting pending join requests is a leadership action.
  def can_moderate_requests?(user)
    can_lead?(user)
  end

  # Who can manage this chapter: a platform admin, the chapter's steward, or an
  # institute owner. The steward branch reads the column on chapters, so it
  # passes with no ChapterMembership at all.
  def can_manage?(user)
    return false unless user
    return true if user.admin?
    return true if steward_id == user.id

    institute.present? && user.institute_owner?(institute)
  end

  def approve_request!(membership)
    membership.approved!
  end

  # Invites are aimed at people who are not already settled members: an existing
  # member with a finished profile is told to be added as a leader instead.
  def generate_steward_invite!(email)
    existing_user = User.find_by(email: email.downcase)
    if existing_user&.member? && existing_user.profile&.setup_completed?
      raise ArgumentError, "Cannot invite an existing member as steward"
    end

    self.steward_invite_token = SecureRandom.urlsafe_base64(32)
    self.steward_invite_email = email.downcase
    save!
  end

  def accept_steward_invite!(user)
    raise ArgumentError, "Email mismatch" unless user.email.downcase == steward_invite_email&.downcase

    user.update!(chapter_steward: true) unless user.chapter_steward?
    # Deliberately NOT account_type: :steward — that marks an *institute*
    # steward, whose home is the /steward section, and entering it requires an
    # accepted InstituteRole. A chapter steward runs their chapter from
    # chapters#manage instead, as a normal member.
    user.switch_to_free! unless user.plan_active?
    self.steward = user
    self.steward_invite_token = nil
    self.steward_invite_email = nil
    save!
  end

  def pending_steward_invite?
    steward_invite_token.present?
  end
end
EOF
cat > "$F4/app/controllers/steward_invites_controller.rb" <<'EOF'
class StewardInvitesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chapter

  def show
    unless current_user.email.downcase == @chapter.steward_invite_email&.downcase
      redirect_to authenticated_root_path, alert: t(".email_mismatch")
      return
    end

    @chapter.accept_steward_invite!(current_user)
    # Chapter stewards manage from the chapter itself, not /steward.
    redirect_to manage_chapter_path(@chapter), notice: t(".success", chapter_name: @chapter.name)
  end

  private

  # The token is cleared on acceptance, so a second visit to the same URL lands
  # here rather than accepting twice.
  def set_chapter
    @chapter = Chapter.find_by(steward_invite_token: params[:token])
    return if @chapter

    redirect_to authenticated_root_path, alert: t(".invalid_token")
  end
end
EOF
cat > "$F4/app/controllers/users/registrations_controller.rb" <<'EOF'
class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      process_pending_steward_invite(resource) if resource.persisted?
    end
  end

  protected

  # Runs inside Devise's create block, before after_sign_up_path_for is called.
  # This is what assigns chapters.steward_id for a brand-new account.
  def process_pending_steward_invite(resource)
    token = session.delete(:pending_steward_invite_token)
    return if token.blank?

    chapter = Chapter.find_by(steward_invite_token: token)
    return if chapter.nil?
    return unless chapter.steward_invite_email&.downcase == resource.email.downcase

    chapter.accept_steward_invite!(resource)
  end

  def after_sign_up_path_for(resource)
    return steward_root_path if resource.steward_for_any_institute?

    # A chapter steward lands on the chapter they were invited to run; /steward
    # is for institute stewards and would turn them away.
    chapter = Chapter.find_by(steward_id: resource.id)
    return manage_chapter_path(chapter) if chapter

    # Profile setup first, then payment
    step_profile_setup_path(step: 1)
  end
end
EOF
cat > "$F4/test/models/chapter_test.rb" <<'EOF'
require "test_helper"

class ChapterTest < ActiveSupport::TestCase
  setup do
    @chapter = chapters(:downtown)
  end

  test "generate_steward_invite! stores a token and the invited email" do
    @chapter.generate_steward_invite!("New.Steward@example.com")

    assert @chapter.pending_steward_invite?
    assert_equal "new.steward@example.com", @chapter.steward_invite_email
  end

  test "generate_steward_invite! refuses a settled member" do
    settled = User.create!(email: "settled@example.com", password: "password123")
    settled.profile.update!(setup_completed_at: Time.current)

    assert_raises(ArgumentError) { @chapter.generate_steward_invite!(settled.email) }
  end

  test "accept_steward_invite! makes the user the chapter steward" do
    invite_email = "steward.#{SecureRandom.hex(4)}@example.com"
    @chapter.generate_steward_invite!(invite_email)

    new_user = User.create!(email: invite_email, password: "password123")

    @chapter.accept_steward_invite!(new_user)

    assert new_user.reload.chapter_steward?
    # A chapter steward stays a member: account_type steward means an *institute*
    # steward, and without an InstituteRole it would bounce them between / and
    # /steward forever.
    assert_not new_user.steward?
    assert_equal new_user, @chapter.reload.steward
    assert_nil @chapter.steward_invite_token
    assert_nil @chapter.steward_invite_email
  end

  test "accept_steward_invite! puts an unpaid steward on the free Community plan" do
    invite_email = "steward.free.#{SecureRandom.hex(4)}@example.com"
    @chapter.generate_steward_invite!(invite_email)

    new_user = User.create!(email: invite_email, password: "password123", plan: :circle)
    assert_not new_user.plan_active?

    @chapter.accept_steward_invite!(new_user)

    new_user.reload
    assert new_user.community?
    assert new_user.plan_active?
  end

  test "accept_steward_invite! leaves an active plan untouched" do
    invite_email = "steward.paid.#{SecureRandom.hex(4)}@example.com"
    @chapter.generate_steward_invite!(invite_email)

    new_user = User.create!(email: invite_email, password: "password123")
    new_user.activate_plan!(tier: :everywhere)

    @chapter.accept_steward_invite!(new_user)

    assert new_user.reload.everywhere?
  end

  test "accept_steward_invite! raises on email mismatch" do
    @chapter.generate_steward_invite!("someone.else@example.com")
    other = User.create!(email: "wrong.person@example.com", password: "password123")

    assert_raises(ArgumentError) { @chapter.accept_steward_invite!(other) }
  end

  test "can_manage? accepts the steward with no membership" do
    user = User.create!(email: "steward.only@example.com", password: "password123")
    @chapter.update!(steward: user)

    assert @chapter.can_manage?(user)
    assert_empty @chapter.chapter_memberships.approved.where(user: user)
  end
end
EOF
cat > "$F4/test/controllers/steward_invites_controller_test.rb" <<'EOF'
require "test_helper"

class StewardInvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chapter = chapters(:downtown)
    @bob = users(:bob)
    @chapter.update!(steward_invite_token: "test-invite-token-123",
                     steward_invite_email: @bob.email)
    sign_in @bob
  end

  test "accepting the invite makes bob the chapter steward" do
    get steward_invite_path(token: "test-invite-token-123")

    # Chapter stewards manage from the chapter, not the /steward section.
    assert_redirected_to manage_chapter_path(@chapter)
    assert @bob.reload.chapter_steward?
    assert_not @bob.steward?
    assert_equal @bob, @chapter.reload.steward
    assert_nil @chapter.steward_invite_token
    assert_nil @chapter.steward_invite_email
  end

  test "a mismatched email is turned away" do
    sign_in users(:member)

    get steward_invite_path(token: "test-invite-token-123")

    assert_redirected_to authenticated_root_path
    assert_not users(:member).reload.chapter_steward?
  end

  test "an unknown token is turned away" do
    get steward_invite_path(token: "no-such-token")

    assert_redirected_to authenticated_root_path
  end
end
EOF
cat > "$F4/test/controllers/steward_section_redirect_test.rb" <<'EOF'
require "test_helper"

# The /steward section admits users with an accepted InstituteRole
# (Steward::BaseController#authorize_steward!). Redirecting people there on
# account_type alone sent anyone carrying the flag without a role into an endless
# / <-> /steward bounce, which reads to them as "I can't log in".
class StewardSectionRedirectTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def follow_redirects(limit: 10)
    hops = []
    limit.times do
      break unless response.redirect?
      hops << response.location.sub("http://www.example.com", "")
      follow_redirect!
    end
    hops
  end

  test "account_type steward without an institute role is not sent to /steward" do
    user = User.create!(
      email: "stray-steward@test.com",
      password: "password123",
      account_type: :steward,
      plan: :community
    )
    assert_not user.steward_for_any_institute?
    sign_in user

    get authenticated_root_path
    hops = follow_redirects

    assert_not_includes hops, "/steward"
    assert_response :success
  end

  test "a chapter steward reaches their chapter's manage page" do
    user = User.create!(email: "chapter-steward@test.com", password: "password123",
                        plan: :community, chapter_steward: true)
    chapter = Chapter.create!(
      name: "Redirect Test Chapter",
      description: "Chapter used to check steward routing",
      discoverable: true,
      active: true,
      join_policy: :closed,
      steward: user
    )
    chapter.chapter_memberships.create!(
      user: user, role: :leader, status: :approved, joined_at: Time.current
    )
    Flipper.enable(:chapter_hubs)
    sign_in user

    get manage_chapter_path(chapter)

    assert_response :success
  end

  test "an institute steward is still sent to /steward" do
    user = users(:institute_steward)
    assert user.steward_for_any_institute?
    sign_in user

    get authenticated_root_path

    assert_redirected_to steward_root_path
  end
end
EOF
git -C "$F4" checkout -q -b fix/steward-redirect-loop
commit "$F4" "Stop chapter stewards from looping between / and /steward

- Only redirect to the steward section users who can enter it (an accepted
  InstituteRole); redirecting on account_type alone bounced flag-carrying users
  without a role forever
- Chapter steward invites no longer set account_type steward, and put unpaid
  stewards on the free Community plan, so they run their chapter from
  chapters#manage as members
- Send chapter stewards to their chapter after accepting an invite or signing up,
  instead of the institute-only /steward dashboard"

# Link rung 3: a GitHub remote with nothing pushed, so citations are plain text
# and the page has to say why. Same rung as F2, reached the same way — and the
# reason it is not higher is worth recording, because the first attempt got it
# wrong.
#
# That attempt pushed the branch to a local bare repo and then rewrote the remote
# URL to this GitHub one, on the theory that the ladder's reachability test is
# `git branch -r --contains HEAD`, which reads refs/remotes and never contacts a
# server. It does, and the trick worked — on the check script. The first live run
# against this fixture ran `gh` anyway, got "Could not resolve to a Repository",
# and correctly emitted plain text, because acme/commons does not exist and a
# permalink to it would 404 whatever refs/remotes says.
#
# So rung 2 is not reachable with a fictional remote: a run that reasons about
# the world will always decline it, and it is right to. Worse, the trick put a
# hole in `checks/page-invariants.sh` § 5 — with refs/remotes populated, that
# check greenlights a page of dead permalinks, which is exactly the
# always-passing check this repository warns about. Rungs 1 and 2 need a real
# reachable repository, and are therefore out of scope for an offline fixture.
git -C "$F4" remote add origin https://github.com/acme/commons.git

echo "fixtures built in $DEST"
for d in "$F1" "$F2" "$F3" "$F4"; do
  printf '\n%s\n' "$(basename "$d")"
  echo "  base: $(git -C "$d" rev-parse --short HEAD~1)  head: $(git -C "$d" rev-parse --short HEAD)  branch: $(git -C "$d" rev-parse --abbrev-ref HEAD)"
  echo "  remote: $(git -C "$d" remote get-url origin 2>/dev/null || echo none)"
  git -C "$d" diff --name-only HEAD~1...HEAD | sed 's/^/  /'
done
