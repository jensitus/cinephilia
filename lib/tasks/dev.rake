namespace :dev do
  desc "Reset schedules to future dates for development"
  task refresh_schedules: :environment do
    Schedule.find_each do |schedule|
      # Move old schedules to future dates
      if schedule.time < Date.today
        schedule.update(time: Date.today + rand(1..30).days)
      end
    end

    puts "Schedules refreshed! #{Schedule.where('time >= ?', Date.today).count} future schedules."
  end
end
