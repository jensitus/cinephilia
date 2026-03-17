class Search
  attr_reader :query

  def initialize(query)
    @query = query
  end

  def results
    return {} if query.blank?

    {
      movies_current: Movie.search(query).currently_showing,
      movies_archived: Movie.search(query).not_currently_showing,
      cinemas: Cinema.search(query),
      genres: Genre.search(query).includes(:movies).limit(10),
      people: Person.search(query).includes(:movies)
    }
  end

  def total_count
    results.values.sum(&:count)
  end
end
