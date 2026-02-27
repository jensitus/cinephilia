class CrawlerMailerPreview < ActionMailer::Preview
  def failure_report
    failures = [
      {
        crawler:   "KinoFulpmesCrawlerService",
        error:     "Connection refused - connect(2) for \"www.kino-fulpmes.at\" port 443",
        backtrace: [
          "app/services/crawlers/kino_fulpmes_crawler_service.rb:122:in `fetch_page'",
          "app/services/crawlers/kino_fulpmes_crawler_service.rb:37:in `film_entries'",
          "app/services/crawlers/kino_fulpmes_crawler_service.rb:17:in `call'"
        ]
      },
      {
        crawler:   "WulfeniaKinoCrawlerService",
        error:     "execution expired",
        backtrace: [
          "app/services/crawlers/wulfenia_kino_crawler_service.rb:45:in `fetch_data'",
          "app/services/crawlers/wulfenia_kino_crawler_service.rb:12:in `call'"
        ]
      }
    ]
    CrawlerMailer.failure_report(failures)
  end
end
