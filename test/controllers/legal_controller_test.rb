require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get legal_url
    assert_response :success
  end
end
