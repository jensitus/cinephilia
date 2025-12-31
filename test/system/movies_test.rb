# test/system/movies_test.rb
require "application_system_test_case"

class MoviesTest < ApplicationSystemTestCase
  test "visiting the movie index" do
    visit movies_url

    assert_selector "h1", text: "Movies"
  end

  test "user can view movie with cast and crew" do
    movie = movies(:one)
    director = people(:director_one)
    actor = people(:actor_one)

    # Create credits
    Credit.create!(movie: movie, person: director, role: "crew", job: "Director")
    Credit.create!(movie: movie, person: actor, role: "cast", character: "Hero", order: 1)

    visit movie_url(movie)

    # Verify movie details
    assert_text movie.title
    assert_text movie.description

    # Verify director
    assert_text "Directors:"
    assert_text director.name

    # Verify cast
    assert_text "Actors:"
    assert_text actor.name
  end
end
