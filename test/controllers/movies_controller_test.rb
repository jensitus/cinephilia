require "test_helper"

class MoviesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get movies_url
    assert_response :success
  end

  test "should get show" do
    movie = movies(:one)
    get movie_url(movie)
    assert_response :success
  end
end
