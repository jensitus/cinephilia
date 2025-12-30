class StartPageController < ApplicationController
  before_action :set_movies
  before_action :cinemas_for_homepage
  before_action :get_tags

  VOTIV_KINO = "Votiv Kino"
  DE_FRANCE = "De France"
  SCHIKANEDER = "Schikaneder"
  GARTENBAU_KINO = "Gartenbaukino"
  BURG_KINO = "Burg Kino"
  TOP_KINO = "Top Kino"

  def home
  end

  private

  def cinemas_for_homepage
    @movie_hash = Hash.new
    @movie_hash.update VOTIV_KINO     => @votiv
    @movie_hash.update TOP_KINO       => @top_kino
    @movie_hash.update DE_FRANCE      => @de_france
    @movie_hash.update GARTENBAU_KINO => @gartenbau
    @movie_hash.update BURG_KINO      => @burg
  end

  def set_movies
    @votiv     =  Cinema.get_random_movie_for_start_page VOTIV_KINO
    @top_kino  =  Cinema.get_random_movie_for_start_page TOP_KINO
    @de_france =  Cinema.get_random_movie_for_start_page DE_FRANCE
    @gartenbau =  Cinema.get_random_movie_for_start_page GARTENBAU_KINO
    @burg      =  Cinema.get_random_movie_for_start_page BURG_KINO
  end

  def get_tags
    @tags = Tag.all
    @tags.delete(Tag.left_outer_joins(:schedules).where(schedules: { id: nil }))
  end

end
