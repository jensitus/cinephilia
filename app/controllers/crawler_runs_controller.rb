class CrawlerRunsController < ApplicationController
  skip_after_action :track_page_view

  http_basic_authenticate_with(
    name:     Rails.application.credentials.dig(:dashboard, :username),
    password: Rails.application.credentials.dig(:dashboard, :password)
  )

  def index
    @runs = CrawlerRun.recent.limit(50)

    cinema_crawler_map = {}
    Crawlers::BaseCrawlerService.all_crawlers.each do |klass|
      crawler_name = klass.name.demodulize
      klass.cinema_ids.each { |id| cinema_crawler_map[id] = crawler_name }
    end

    cinemas_by_id = Cinema.where(cinema_id: cinema_crawler_map.keys).index_by(&:cinema_id)
    @crawled_cinemas = cinema_crawler_map.filter_map do |cinema_id, crawler|
      cinema = cinemas_by_id[cinema_id]
      [ cinema, crawler ] if cinema
    end

    @views_today   = PageView.humans.since(Date.today).count
    @views_7_days  = PageView.humans.since(7.days.ago).count
    @views_30_days = PageView.humans.since(30.days.ago).count
    @bots_today    = PageView.where(is_bot: true).since(Date.today).count
    @daily_counts  = PageView.daily_counts(days: 14)

    top_movie_ids   = PageView.top_movies(limit: 5)
    top_cinema_ids  = PageView.top_cinemas(limit: 5)

    movies  = Movie.where(id: top_movie_ids.keys).index_by(&:id)
    cinemas = Cinema.where(id: top_cinema_ids.keys).index_by(&:id)

    @top_movies    = top_movie_ids.map  { |id, count| [ movies[id],  count ] }.select { |m, _| m }
    @top_cinemas   = top_cinema_ids.map { |id, count| [ cinemas[id], count ] }.select { |c, _| c }
    @views_by_county = PageView.by_county(days: 30)
  end
end
