require "test_helper"

class CinemasControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get cinemas_url
    assert_response :success
  end

  test "should get show" do
    cinema = cinemas(:one)
    get cinema_url(cinema)
    assert_response :success
  end
end
