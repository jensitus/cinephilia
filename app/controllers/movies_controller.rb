class MoviesController < ApplicationController
  before_action :set_movie, only: [ :show ]
  before_action :set_movie_schedules, only: [ :show ]

  def index
    @movies = Movie.all
  end

  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_movie
    @movie = Movie.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def movie_params
    params.expect(movie: [ :movie_id, :title, :description ])
  end

  def set_movie_schedules
    @movie_schedules = @movie.schedules
                             .group_by { |schedule| Time.at(schedule.time).strftime("%d.%m.") }
                             .collect { |timeslot, schedule| [timeslot, Hash[schedule.group_by { |s| s.cinema.title }]] }
  end
end
