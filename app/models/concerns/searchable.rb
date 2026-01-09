module Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) {
      return none if query.blank?

      language = self == Movie ? "german" : "english"

      where("search_vector @@ plainto_tsquery('#{language}', ?)", query)
        .order(Arel.sql(sanitize_sql_array("ts_rank(search_vector, plainto_tsquery('#{language}', '#{sanitize_sql_like(query)}')) DESC")))
    }
  end

  def update_search_vector!
    # Subclasses should override this with their specific fields
    raise NotImplementedError, "Subclass must implement update_search_vector!"
  end
end
