class StartPageController < ApplicationController
  before_action :set_movies_with_cinemas
  before_action :get_tags

  def home
    @heading = Cinephilia::Config::FEATURED_CINEMAS.to_sentence(last_word_connector: " and ")
  end

  private

  def set_movies_with_cinemas
    @movies_with_cinemas = Movie.movies_with_cinemas_for_startpage(Cinephilia::Config::FEATURED_CINEMAS)
  end

  def get_tags
    @tags = Tag.with_schedules
  end
end
