class Genre < ApplicationRecord
  include Searchable

  has_and_belongs_to_many :movies

  def currently_showing_movies
    movies.currently_showing.order(:title)
  end

  def archived_movies
    movies.not_currently_showing.order(:title)
  end

  scope :find_or_create_genre, ->(genre) do
    genre = Genre.find_or_initialize_by(name: genre)
    genre.save if genre.new_record?
    genre
  end
end
