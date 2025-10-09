require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get legal_show_url
    assert_response :success
  end
end
