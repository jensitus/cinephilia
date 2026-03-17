class Genre < ApplicationRecord
  has_and_belongs_to_many :movies

  validates :name, presence: true, uniqueness: true

  scope :search, ->(query) {
    return none if query.blank?

    where("search_vector @@ plainto_tsquery('german', ?)", query)
      .order(
        Arel.sql(
          sanitize_sql_array([
            "ts_rank(search_vector, plainto_tsquery('german', '#{sanitize_sql_like(query)}')) DESC"
          ])
        )
      )
  }

  def currently_showing_movies
    movies.currently_showing.order(:title)
  end

  def archived_movies
    movies.not_currently_showing.order(:title)
  end

  def self.find_or_create_genre(genre_name)
    genre = find_or_initialize_by(name: genre_name)
    genre.save if genre.new_record?
    genre
  end
end
