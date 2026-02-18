class TagsController < ApplicationController
  before_action :set_tag, only: [:show]
  before_action :set_movie_schedules, only: [:show]

  def index
    @tags = Tag.with_schedules
  end

  def show
  end

  private

  def set_tag
    @tag = Tag.find(params.expect(:id))
  end

  def set_movie_schedules
    schedules_by_date = @tag.schedules
                            .includes(:cinema, :movie)
                            .order(:time)
                            .group_by { |schedule| schedule.time.strftime("%d.%m.") }

    @movie_schedules = schedules_by_date.transform_values do |schedules|
      schedules.group_by { |schedule| schedule.cinema.title }.to_h
    end
  end
end
