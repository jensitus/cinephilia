class CinemasController < ApplicationController
  before_action :set_cinema, only: %i[show]
  before_action :set_cinema_schedules, only: %i[show]

  def index
    @cinemas = Cinema.in_county(current_county)
  end

  def show
    @_page_view_viewable = @cinema
  end

  private

  def set_cinema
    @cinema = Cinema.find(params.expect(:id))
  end

  def cinema_params
    params.expect(cinema: [ :cinema_id, :title, :county, :uri ])
  end

  def set_cinema_schedules
    schedules_by_date = @cinema.schedules
                               .includes(:movie, :tags)
                               .order(:time)
                               .group_by { |schedule| schedule.time.strftime("%d.%m.") }

    @cinema_schedules = schedules_by_date.transform_values do |schedules|
      schedules.group_by { |schedule| schedule.movie.title }.to_h
    end
  end
end
