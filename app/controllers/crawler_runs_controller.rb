class CrawlerRunsController < ApplicationController
  http_basic_authenticate_with(
    name:     Rails.application.credentials.dig(:dashboard, :username),
    password: Rails.application.credentials.dig(:dashboard, :password)
  )

  def index
    @runs = CrawlerRun.recent.limit(50)
  end
end
