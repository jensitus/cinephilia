class TagsController < ApplicationController
  before_action :set_tag, only: [ :show ]
  before_action :set_movie_schedules, only: [ :show ]

  def index
    all_austria = current_county == "Österreich"

    tags = Tag.joins(schedules: :cinema)
              .then { |q| all_austria ? q : q.where(cinemas: { county: current_county }) }
              .distinct

    @cinemas_by_tag = Schedule.joins(:tags, :cinema)
                              .where(tags: { id: tags.map(&:id) })
                              .then { |q| all_austria ? q : q.where(cinemas: { county: current_county }) }
                              .distinct
                              .pluck("tags.id", "cinemas.title")
                              .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(tag_id, cinema_title), hash|
      hash[tag_id] |= [ cinema_title ]
    end

    tags_by_cinema = Hash.new { |h, k| h[k] = [] }
    tags.each do |tag|
      (@cinemas_by_tag[tag.id] || []).sort.each { |cinema| tags_by_cinema[cinema] << tag }
    end
    @tags_by_cinema = tags_by_cinema.sort_by { |cinema, _| cinema }.to_h
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
