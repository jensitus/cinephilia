class MoviesController < ApplicationController
  before_action :set_movie, only: [:show]
  before_action :set_movie_schedules, only: [:show]

  def index
    movies = Movie.in_county(current_county).order(title: :asc)
    @movies_by_letter = movies.group_by { |movie| movie.title[0].upcase }
                              .transform_values { |movies| movies.map { |m| { id: m.id, title: m.title, poster_path: m.poster_path } } }
  end

  def show
  end

  private

  def set_movie
    @movie = Movie.includes(credits: :person).find(params[:id])
  end

  def movie_params
    params.expect(movie: [:movie_id, :title, :description])
  end

  def set_movie_schedules
    schedules_by_date = @movie.schedules
                              .in_county(current_county)
                              .includes(:cinema, :tags)
                              .order(:time)
                              .group_by { |schedule| schedule.time.strftime("%d.%m.") }

    @movie_schedules = schedules_by_date.transform_values do |schedules|
      schedules.group_by { |schedule| schedule.cinema.title }.to_h
    end
  end
end
