require "test_helper"

class StartPageControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get start_page_home_url
    assert_response :success
  end
end
