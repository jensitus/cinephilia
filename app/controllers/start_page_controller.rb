class StartPageController < ApplicationController
  before_action :set_movies_with_cinemas
  before_action :get_tags

  FEATURED_CINEMAS = [
    "Votiv Kino",
    "Top Kino",
    "De France",
    "Gartenbaukino",
    "Burg Kino",
    "Schikaneder"
  ].freeze

  def home
    @heading = FEATURED_CINEMAS.to_sentence
  end

  private

  def set_movies_with_cinemas
    @movies_with_cinemas = Movie.movies_with_cinemas_for_startpage(FEATURED_CINEMAS)
  end

  def get_tags
    @tags = Tag.all
    @tags.delete(Tag.left_outer_joins(:schedules).where(schedules: { id: nil }))
  end
end
