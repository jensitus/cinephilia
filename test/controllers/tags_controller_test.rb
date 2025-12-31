require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get tags_url
    assert_response :success
  end

  test "should get show" do
    tag = tags(:one)
    get tag_url(tag)
    assert_response :success
  end
end
