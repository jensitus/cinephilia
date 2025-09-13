class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :cinema
  has_and_belongs_to_many :tags

  scope :movie_id, -> (mov_id) { where movie_id: mov_id }
  scope :cinema_id, -> (cinema_id) { where cinema_id: cinema_id }
  scope :time, -> (time) { where time: time }

  scope :create_schedule, -> (screening, movie_id, cinema_id) do
    schedule_id = "s-" + movie_id.to_s + "-" + cinema_id.to_s + "-" + screening["time"]
    begin
      schedule = Schedule.create(time:        screening["time"],
                                 three_d:     screening["3d"],
                                 ov:          screening["ov"],
                                 info:        screening["info"],
                                 movie_id:    movie_id,
                                 cinema_id:   cinema_id,
                                 schedule_id: schedule_id)
      schedule.save
    rescue Exception => ex
      Rails.logger.error "ERROR " + ex.to_s
      schedule = Schedule.find_by(schedule_id: schedule_id)
    end
    schedule
  end

  # def self.create_schedule(screening, movie_id, cinema_id)
  #   schedule_id = "s-" + movie_id.to_s + "-" + cinema_id.to_s + "-" + screening["time"]
  #   Schedule.movie_id(movie_id).cinema_id(cinema_id).time(screening["time"])
  #   begin
  #     schedule_created = Schedule.create!(time: screening["time"],
  #                                         three_d: screening["3d"],
  #                                         ov: screening["ov"],
  #                                         info: screening["info"],
  #                                         movie_id: movie_id,
  #                                         cinema_id: cinema_id,
  #                                         schedule_id: schedule_id)
  #   rescue Exception => ex
  #     Rails.logger.error "ERROR " + ex.to_s
  #     schedule_created = Schedule.find_by(schedule_id: schedule_id)
  #   end
  #   schedule_created
  # end

end
