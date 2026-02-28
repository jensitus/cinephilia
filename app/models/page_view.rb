class PageView < ApplicationRecord
  belongs_to :viewable, polymorphic: true, optional: true

  BOT_UA_PATTERN = /bot|crawl|slurp|spider|mediapartners|facebookexternalhit|
                    whatsapp|pinterest|linkedinbot|twitterbot|applebot|
                    semrushbot|ahrefsbot|mj12bot|dotbot|yandex|baiduspider|
                    duckduckbot|sogou|exabot|ia_archiver|python-requests|
                    curl|wget|libwww|java\/|go-http-client/xi

  scope :since,  ->(time) { where("occurred_at >= ?", time) }
  scope :humans, -> { where(is_bot: false) }

  def self.bot?(user_agent)
    return true if user_agent.blank?

    BOT_UA_PATTERN.match?(user_agent)
  end

  def self.daily_counts(days: 7)
    humans.since(days.days.ago).group("DATE(occurred_at)")
                               .order("DATE(occurred_at)")
                               .count
  end

  def self.top_movies(limit: 5, days: 30)
    humans.since(days.days.ago).where(viewable_type: "Movie")
                               .group(:viewable_id)
                               .order("count_all DESC")
                               .limit(limit)
                               .count
  end

  def self.by_county(days: 30)
    humans.since(days.days.ago).where.not(county: nil)
                               .group(:county)
                               .order("count_all DESC")
                               .count
  end

  def self.top_cinemas(limit: 5, days: 30)
    humans.since(days.days.ago).where(viewable_type: "Cinema")
                               .group(:viewable_id)
                               .order("count_all DESC")
                               .limit(limit)
                               .count
  end
end
