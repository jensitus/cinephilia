class MoviesController < ApplicationController
  before_action :set_movie, only: [ :show ]
  before_action :set_movie_schedules, only: [ :show ]

  def index
    movies = Movie.joins(:schedules).distinct.order(title: :asc)
    @movies_by_letter = movies.group_by { |movie| movie.title[0].upcase }
                              .transform_values { |movies| movies.map { |m| { id: m.id, title: m.title, poster_path: m.poster_path } } }
  end

  def show
    # @movie = Movie.includes(credits: :person).find(params[:id])
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_movie
    @movie = Movie.includes(credits: :person).find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def movie_params
    params.expect(movie: [ :movie_id, :title, :description ])
  end

  def set_movie_schedules
    # Group schedules by date (dd.mm.)
    schedules_by_date = @movie.schedules.order(:time).group_by do |schedule|
      schedule.time.strftime("%d.%m.")
    end

    # Create a hash where each date maps to another hash, grouping by cinema title
    @movie_schedules = schedules_by_date.transform_values do |schedules|
      schedules.group_by { |schedule| schedule.cinema.title }.to_h
    end

  end
end
