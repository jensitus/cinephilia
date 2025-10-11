class TagsController < ApplicationController
  before_action :set_tag, only: [:show]
  before_action :set_movie_schedules, only: [:show]

  def index
    @tags = Tag.all
    @tags.delete(Tag.left_outer_joins(:schedules).where(schedules: { id: nil }))
  end

  def show

  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_tag
    @tag = Tag.find(params.expect(:id))
  end

  def set_movie_schedules

    schedules_by_date = @tag.schedules.order(:time).group_by do |schedule|
      schedule.time.strftime("%d.%m.")
    end

    @movie_schedules = schedules_by_date.transform_values do |schedules|
      schedules.group_by { |schedule| schedule.cinema.title }.to_h
    end

  end

end
