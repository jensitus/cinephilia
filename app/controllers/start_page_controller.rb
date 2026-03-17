class StartPageController < ApplicationController
  before_action :set_movies_with_cinemas
  before_action :get_tags

  def home
    @heading = featured_cinema_titles.to_sentence(last_word_connector: " and ")
  end

  private

  def set_movies_with_cinemas
    @movies_with_cinemas = Movie.movies_with_cinemas_for_startpage(featured_cinema_titles)
  end

  def get_tags
    @tags = Tag.joins(schedules: :cinema)
               .where(cinemas: { county: current_county })
               .distinct
  end

  def featured_cinema_titles
    @featured_cinema_titles ||= begin
      cinemas = Cinephilia::Config::FEATURED_CINEMAS[current_county]
      if cinemas.present?
        cinemas
      else
        Cinema.in_county(current_county).pluck(:title)
      end
    end
  end
end
