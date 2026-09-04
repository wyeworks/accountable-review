class Project < ApplicationRecord
  scope :selectable, -> { where(archived_at: nil) }

  def archive!
    update!(archived_at: Time.current)
  end

  # An enum, for the probe rule: `Project.statuses` is generated and has no `def`.
  enum :status, { open: 0, closed: 1 }
end
