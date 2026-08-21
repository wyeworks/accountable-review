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
printf '# Timesheet\n\nA time tracking aplication.\n' > "$F3/README.md"
commit "$F3" "base"
printf '# Timesheet\n\nA time tracking application.\n' > "$F3/README.md"
git -C "$F3" checkout -q -b fix-typo
commit "$F3" "Fix typo in README"

echo "fixtures built in $DEST"
for d in "$F1" "$F2" "$F3"; do
  printf '\n%s\n' "$(basename "$d")"
  echo "  base: $(git -C "$d" rev-parse --short HEAD~1)  head: $(git -C "$d" rev-parse --short HEAD)  branch: $(git -C "$d" rev-parse --abbrev-ref HEAD)"
  echo "  remote: $(git -C "$d" remote get-url origin 2>/dev/null || echo none)"
  git -C "$d" diff --name-only HEAD~1...HEAD | sed 's/^/  /'
done
