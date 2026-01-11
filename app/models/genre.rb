class Genre < ApplicationRecord
  # include Searchable

  has_and_belongs_to_many :movies

  scope :search, ->(query) {
    return none if query.blank?

    where("search_vector @@ plainto_tsquery('german', ?)", query)
      .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('german', '#{sanitize_sql_like(query)}')) DESC"))
  }

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
