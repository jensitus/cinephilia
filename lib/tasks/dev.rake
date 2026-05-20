namespace :dev do
  desc "Run the full fetch pipeline manually (crawlers + film.at fixture)"
  task fetch: :environment do
    Movie.set_date
  end

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

  task test_crawler: :environment do
    Crawlers::FilmarchivCrawlerService.new.call
  end

  task test_votiv_crawler: :environment do
    Crawlers::VotivKinoCrawlerService.new.call
  end

  task test_leokino_crawler: :environment do
    Crawlers::LeokinoCrawlerService.new.call
  end
end
