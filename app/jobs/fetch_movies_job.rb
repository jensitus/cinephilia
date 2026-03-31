class FetchMoviesJob < ApplicationJob
  queue_as :default

  def perform
    Movie.set_date
  end
end
