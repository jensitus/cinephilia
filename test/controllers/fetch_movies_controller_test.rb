require "test_helper"

class FetchMoviesControllerTest < ActionDispatch::IntegrationTest
  test "should get get" do
    get fetch_movies_get_url
    assert_response :success
  end
end
