class TagsController < ApplicationController
  before_action :set_tag, only: [:show]
  before_action :set_movie_schedules, only: [:show]

  def index
    @tags = Tag.joins(schedules: :cinema)
               .where(cinemas: { county: current_county })
               .distinct

    @cinemas_by_tag = Schedule.joins(:tags, :cinema)
                              .where(tags: { id: @tags.map(&:id) })
                              .where(cinemas: { county: current_county })
                              .distinct
                              .pluck("tags.id", "cinemas.title")
                              .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(tag_id, cinema_title), hash|
      hash[tag_id] |= [cinema_title]
    end
  end

  def show
  end

  private

  def set_tag
    @tag = Tag.find_by!(slug: params[:slug])
  end

  def set_movie_schedules
    schedules_by_date = @tag.schedules
                            .in_county(current_county)
                            .includes(:cinema, :movie)
                            .order(:time)
                            .group_by { |schedule| schedule.time.strftime("%d.%m.") }

    @movie_schedules = schedules_by_date.transform_values do |schedules|
      schedules.group_by { |schedule| schedule.cinema.title }.to_h
    end
  end
end
