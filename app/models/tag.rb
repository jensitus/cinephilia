class Tag < ApplicationRecord
  has_and_belongs_to_many :schedules

  validates :name, :tag_id, presence: true, uniqueness: true

  scope :with_schedules, -> { joins(:schedules).distinct }

  def self.find_or_create_tag(tag_name)
    tag_id = "t-#{tag_name.downcase.gsub(' ', '-')}"
    tag = find_or_initialize_by(name: tag_name)
    tag.tag_id = tag_id
    tag.save if tag.new_record?
    tag
  end
end
