class Search
  attr_reader :query

  def initialize(query)
    @query = query
  end

  def results
    return {} if query.blank?

    {
      movies: Movie.search(query).limit(10),
      cinemas: Cinema.search(query).limit(10),
      genres: Genre.search(query).includes(:movies).limit(10),
      people: Person.search(query).includes(:movies).limit(10)
    }
  end

  def total_count
    results.values.sum(&:count)
  end
end
