class CrawlerRun < ApplicationRecord
  scope :recent, -> { order(ran_at: :desc) }

  def failed?
    failures.any?
  end

  def success?
    failures.empty?
  end
end
