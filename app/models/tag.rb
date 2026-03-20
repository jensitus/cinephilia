class Tag < ApplicationRecord
  has_and_belongs_to_many :schedules

  validates :name, :tag_id, presence: true, uniqueness: true

  scope :with_schedules, -> { joins(:schedules).distinct }

  def self.find_or_create_tag(tag_name, description: nil)
    tag_id = "t-#{tag_name.downcase.gsub(' ', '-')}"
    tag = find_or_initialize_by(name: tag_name)
    tag.tag_id  = tag_id
    tag.slug    = slug_from_name(tag_name) if tag.slug.blank?
    tag.description = description if description.present?
    tag.save if tag.new_record? || tag.changed?
    tag
  end

  def to_param
    slug
  end

  def self.slug_from_name(name)
    parts = name.split(/:\s*/, 2)
    parts.map(&:parameterize).join("/")
  end
end
