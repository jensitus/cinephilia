require "test_helper"

class CinemaTest < ActiveSupport::TestCase
  setup do
    Cinema.update_all(
      "search_vector = to_tsvector('german', coalesce(title,'') || ' ' || coalesce(city,'') || ' ' || coalesce(county,''))"
    )
  end

  test "search finds cinemas by county" do
    assert_includes Cinema.search("Wien"), cinemas(:one)
  end

  test "search finds cinemas by city" do
    cinema = Cinema.create!(cinema_id: "t-alpenkino", title: "Alpenkino", county: "Tirol", city: "Innsbruck")
    Cinema.where(id: cinema.id).update_all(
      "search_vector = to_tsvector('german', coalesce(title,'') || ' ' || coalesce(city,'') || ' ' || coalesce(county,''))"
    )
    assert_includes Cinema.search("Innsbruck"), cinema
  end

  test "currently_showing includes cinemas with future schedules" do
    cinema = Cinema.create!(cinema_id: "t-active-kino", title: "Active Kino", county: "Wien")
    Schedule.create!(time: 1.year.from_now, three_d: false, ov: false, info: "",
                     movie: movies(:one), cinema: cinema, schedule_id: "s-active-test")
    assert_includes Cinema.currently_showing, cinema
  end

  test "currently_showing excludes cinemas without future schedules" do
    refute_includes Cinema.currently_showing, cinemas(:one)
  end

  test "not_currently_showing includes cinemas without future schedules" do
    assert_includes Cinema.not_currently_showing, cinemas(:one)
  end
end
