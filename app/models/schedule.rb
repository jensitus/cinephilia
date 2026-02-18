class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :cinema
  has_and_belongs_to_many :tags

  validates :time, :movie_id, :cinema_id, :schedule_id, presence: true

  scope :movie_id, ->(mov_id) { where movie_id: mov_id }
  scope :cinema_id, ->(cinema_id) { where cinema_id: cinema_id }
  scope :time, ->(time) { where time: time }
  scope :past, -> { where("time < ?", Date.today) }
  scope :orphaned, -> { left_outer_joins(:movie).where(movie: { id: nil }) }

  def self.create_schedule(screening, movie_id, cinema_id)
    schedule_id = "s-#{movie_id}-#{cinema_id}-#{screening['time']}"
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
      unique_by: "index_schedules_on_time_and_movie_id_and_cinema_id"
    )

    if result.rows.empty?
      Rails.logger.info("Schedule already exists")
    else
      Rails.logger.info(result.inspect)
    end

    find_by(schedule_id: schedule_id)
  end

  def self.delete_old_schedules(_date = nil)
    past.destroy_all
  end

  def self.delete_schedules_without_movies
    orphaned.find_each(&:destroy)
  end

  def self.create_schedules_with_tags(screenings, movie_id, cinema_id)
    screenings.each do |screening|
      schedule = create_schedule(screening, movie_id, cinema_id)
      associate_tags_with_schedule(screening["tags"], schedule) if screening["tags"]
    end
  end

  def self.associate_tags_with_schedule(tags, schedule)
    return unless schedule

    tags.each do |tag_name|
      tag = Tag.find_or_create_tag(tag_name)
      schedule.tags << tag unless schedule.tags.include?(tag)
    end
  end
end
