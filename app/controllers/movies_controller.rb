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
