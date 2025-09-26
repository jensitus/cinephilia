class Genre < ApplicationRecord
  has_and_belongs_to_many :movies

  scope :find_or_create_genre, ->(genre) do
    genre = Genre.find_or_initialize_by(name: genre)
    genre.save if genre.new_record?
    genre
  end

  # def self.find_or_create_genre(genre)
  #   genre = Genre.find_or_initialize_by(name: genre)
  #   genre.save if genre.new_record?
  #   genre
  # end

end
