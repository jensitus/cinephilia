class Tag < ApplicationRecord
  has_and_belongs_to_many :schedules

  scope :find_or_create_tag, ->(tag) do
    tag_id = "t-" + tag.downcase.gsub(" ", "-").downcase
    tag = Tag.find_or_initialize_by(name: tag)
    tag.tag_id = tag_id
    tag.save if tag.new_record?
    tag
  end

  # def self.find_or_create_genre(genre)
  #   genre = Genre.find_or_initialize_by(name: genre)
  #   genre.save if genre.new_record?
  #   genre
  # end
  #   def self.find_or_create_tag(tag)
  #     tag_id = "t-" + tag.downcase.gsub(" ", "-").downcase
  #     puts tag.inspect
  #     tag = Tag.find_or_initialize_by(name: tag)
  #     tag.save if tag.new_record?
  #     tag
  #   end

end
