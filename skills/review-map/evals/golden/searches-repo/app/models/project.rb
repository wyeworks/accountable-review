class Project < ApplicationRecord
  scope :selectable, -> { where(archived_at: nil) }

  def archive!
    update!(archived_at: Time.current)
  end
end
