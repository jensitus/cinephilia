class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :cinema
  has_and_belongs_to_many :tags

  scope :movie_id, ->(mov_id) { where movie_id: mov_id }
  scope :cinema_id, ->(cinema_id) { where cinema_id: cinema_id }
  scope :time, ->(time) { where time: time }

  scope :create_schedule, ->(screening, movie_id, cinema_id) do
    schedule_id = "s-" + movie_id.to_s + "-" + cinema_id.to_s + "-" + screening["time"]
    result = insert(
      {
        time: screening["time"],
        three_d: screening["3d"],
        ov: screening["ov"],
        info: screening["info"],
        movie_id: movie_id,
        cinema_id: cinema_id,
        schedule_id: schedule_id
      },
      unique_by: "index_schedules_on_time_and_movie_id_and_cinema_id")

    if result.rows.empty?
      Rails.logger.info("Schedule already exists")
    else
      Rails.logger.info(result.inspect)
    end
  end

  scope :delete_old_schedules, ->(date) do
    schedules_to_delete = where("time < ?", Date.today)
    schedules_to_delete.destroy_all unless schedules_to_delete.empty?
  end

  scope :delete_schedules_without_movies, -> do
    left_outer_joins(:movie).where(movie: { id: nil }).find_each(&:destroy)
  end

  scope :create_schedules_with_tags, ->(screenings, movie_id, cinema_id) do
    screenings.each do |screening|
      schedule = create_schedule(screening, movie_id, cinema_id)
      associate_tags_with_schedule(screening["tags"], schedule) if screening["tags"]
    end
  end

  scope :associate_tags_with_schedule, ->(tags, schedule) do
    return unless schedule

    tags.each do |tag_name|
      tag = Tag.find_or_create_tag(tag_name)
      schedule.tags << tag unless schedule.tags.include?(tag)
    end
  end

end
