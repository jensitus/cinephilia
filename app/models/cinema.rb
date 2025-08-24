class Cinema < ApplicationRecord
  has_many :schedules
  has_many :movies, through: :schedules
  has_and_belongs_to_many :tags

  VOTIV_KINO  = "Votiv Kino"
  DE_FRANCE   = "De France"
  SCHIKANEDER = "Schikaneder"
  BURG_KINO   = "Burg Kino"

  def self.get_random_movie_for_start_page(cinema)
    Movie.distinct.joins(schedules: :cinema)
         .where(cinemas: { title: [cinema] })
         .select('movies.title, movies.id, movies.description, movies.poster_path, cinemas.title AS cinema_title')
  end

end
