class StartPageController < ApplicationController
  before_action :set_movies
  before_action :cinemas_for_homepage

  VOTIV_KINO = "Votiv Kino"
  DE_FRANCE = "De France"
  SCHIKANEDER = "Schikaneder"
  GARTENBAU_KINO = "Gartenbaukino"
  BURG_KINO = "Burg Kino"

  def home
  end

  private

  def cinemas_for_homepage
    @movie_hash = Hash.new
    @movie_hash.update BURG_KINO      => @burg
    @movie_hash.update GARTENBAU_KINO => @gartenbau
    @movie_hash.update VOTIV_KINO     => @votiv
    @movie_hash.update DE_FRANCE      => @de_france
  end

  def set_movies
    @burg      =  Cinema.get_random_movie_for_start_page BURG_KINO
    @gartenbau =  Cinema.get_random_movie_for_start_page GARTENBAU_KINO
    @votiv     =  Cinema.get_random_movie_for_start_page VOTIV_KINO
    @de_france =  Cinema.get_random_movie_for_start_page DE_FRANCE
  end

end
