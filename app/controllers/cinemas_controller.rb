class CinemasController < ApplicationController
  before_action :set_cinema, only: %i[ show ]
  before_action :set_cinema_schedules, only: %i[ show ]

  # GET /cinemas or /cinemas.json
  def index
    @cinemas = Cinema.all
  end

  # GET /cinemas/1 or /cinemas/1.json
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_cinema
    @cinema = Cinema.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def cinema_params
    params.expect(cinema: [ :cinema_id, :title, :county, :uri ])
  end

  def set_cinema_schedules
    @cinema_schedules =
      @cinema.schedules
             .group_by { |schedule| Time.at(schedule.time).strftime("%d.%m.") }
             .collect { |timeslot, schedule| [timeslot, Hash[schedule.group_by { |s| s.movie.title }]] }
  end
end
