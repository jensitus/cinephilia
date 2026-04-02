require "test_helper"

class Crawlers::FilmmuseumCrawlerServiceTest < ActiveSupport::TestCase
  setup do
    @crawler = Crawlers::FilmmuseumCrawlerService.new
  end

  # ---------------------------------------------------------------------------
  # parse_language
  # ---------------------------------------------------------------------------

  test "parse_language: plain foreign language is OV" do
    result = @crawler.send(:parse_language, "John Lasseter, US 1995; 80 min. Englisch")
    assert_equal({ ov: true, info: "OV" }, result)
  end

  test "parse_language: foreign language with german subtitles is OmdU" do
    result = @crawler.send(:parse_language, "Chantal Akerman, FR 1974; 85 min. Französisch mit dt. UT")
    assert_equal({ ov: true, info: "OmdU" }, result)
  end

  test "parse_language: language with dot in abbreviation is OmdU (Inuktitut case)" do
    result = @crawler.send(:parse_language, "Zacharias Kunuk, CA 2001; 114 min. Inuktitut mit dt. UT")
    assert_equal({ ov: true, info: "OmdU" }, result)
  end

  test "parse_language: foreign language with non-german subtitles is OmU" do
    result = @crawler.send(:parse_language, "Director, JP 2000; 90 min. Japanisch mit engl. UT")
    assert_equal({ ov: true, info: "OmU" }, result)
  end

  test "parse_language: German language returns no OV info" do
    result = @crawler.send(:parse_language, "Director, AT 2000; 90 min. Deutsch")
    assert_equal({ ov: false, info: nil }, result)
  end

  test "parse_language: silent film returns no OV info" do
    result = @crawler.send(:parse_language, "Director, DE 1922; 60 min. Stumm")
    assert_equal({ ov: false, info: nil }, result)
  end

  test "parse_language: no runtime in text returns no OV info" do
    result = @crawler.send(:parse_language, "Director, US 1995; Drehbuch: Someone")
    assert_equal({ ov: false, info: nil }, result)
  end

  test "parse_language: nil returns no OV info" do
    result = @crawler.send(:parse_language, nil)
    assert_equal({ ov: false, info: nil }, result)
  end

  test "parse_language: metadata split across two strongs — runtime strong used" do
    # Toy Story case: first strong has no runtime, second strong has "80 min. Englisch"
    result = @crawler.send(:parse_language, "35mm, Farbe, 80 min. Englisch")
    assert_equal({ ov: true, info: "OV" }, result)
  end

  # ---------------------------------------------------------------------------
  # parse_detail_meta
  # ---------------------------------------------------------------------------

  test "parse_detail_meta: extracts director and year" do
    director, year = @crawler.send(:parse_detail_meta, "Alexander Payne, US 1996; Drehbuch: Alexander Payne")
    assert_equal "Alexander Payne", director
    assert_equal "1996", year
  end

  test "parse_detail_meta: handles multiple country codes" do
    director, year = @crawler.send(:parse_detail_meta, "Mira Nair, IN/GB/FR 1988; Drehbuch: Sooni Taraporevala")
    assert_equal "Mira Nair", director
    assert_equal "1988", year
  end

  test "parse_detail_meta: returns nil director when format unrecognised" do
    director, year = @crawler.send(:parse_detail_meta, "35mm, Farbe, 80 min. Englisch")
    assert_nil director
    assert_equal "0", year
  end

  test "parse_detail_meta: blank text returns nil director and year 0" do
    director, year = @crawler.send(:parse_detail_meta, "")
    assert_nil director
    assert_equal "0", year
  end

  # ---------------------------------------------------------------------------
  # parse_description
  # ---------------------------------------------------------------------------

  test "parse_description: returns nil when no nbsp separator present" do
    html = <<~HTML
      <div class="ver-text">
        <strong class="avtext"><span class="avtext">Im Photoatelier</span></strong>
        <span class="avtext">1932, 35mm, 28 min</span>
      </div>
    HTML
    ver_text = Nokogiri::HTML(html).at_css("div.ver-text")
    assert_nil @crawler.send(:parse_description, ver_text)
  end

  test "parse_description: returns text after nbsp separator" do
    html = <<~HTML
      <div class="ver-text">
        <strong class="avtext"><span class="avtext">Chantal Akerman, FR 1974; 85 min. Französisch</span></strong>
        <span class="avtext">&#160;</span>
        <span class="avtext">Eine junge Frau bricht aus der Enge eines Zimmers auf.</span>
      </div>
    HTML
    ver_text = Nokogiri::HTML(html).at_css("div.ver-text")
    assert_equal "Eine junge Frau bricht aus der Enge eines Zimmers auf.", @crawler.send(:parse_description, ver_text)
  end

  test "parse_description: joins multiple spans and ems after separator" do
    html = <<~HTML
      <div class="ver-text">
        <strong class="avtext"><span class="avtext">Akerman, FR 1974; 85 min. Französisch</span></strong>
        <span class="avtext">&#160;</span>
        <em class="avtext">Je tu il elle</em>
        <span class="avtext"> ist das Spielfilmdebüt von Chantal Akerman.</span>
      </div>
    HTML
    ver_text = Nokogiri::HTML(html).at_css("div.ver-text")
    result = @crawler.send(:parse_description, ver_text)
    assert_includes result, "Je tu il elle"
    assert_includes result, "ist das Spielfilmdebüt"
  end

  # ---------------------------------------------------------------------------
  # parse_short_films
  # ---------------------------------------------------------------------------

  test "parse_short_films: ungrouped compilation (Academy Reel style)" do
    html = <<~HTML
      <div class="ver-text">
        <strong class="avtext"><span class="avtext">Studio Bankside</span></strong>
        <span class="avtext">Derek Jarman, GB 1972; 7 min</span>
        <strong class="avtext"><span class="avtext">Journey to Avebury</span></strong>
        <span class="avtext">Derek Jarman, GB 1973; 10 min</span>
      </div>
    HTML
    ver_text = Nokogiri::HTML(html).at_css("div.ver-text")
    entries = @crawler.send(:parse_short_films, ver_text)

    assert_equal 2, entries.size
    assert_equal "Studio Bankside", entries[0][:title]
    assert_equal "Derek Jarman, GB 1972; 7 min", entries[0][:meta]
    assert_nil entries[0][:group]
    assert_equal "Journey to Avebury", entries[1][:title]
  end

  test "parse_short_films: grouped compilation (Programm 54 style)" do
    html = <<~HTML
      <div class="ver-text">
        <span class="avtext">Karl Valentin</span>
        <strong class="avtext"><span class="avtext">Im Photoatelier</span></strong>
        <span class="avtext">1932, 35mm, 28 min</span>
        <strong class="avtext"><span class="avtext">Theaterbesuch</span></strong>
        <span class="avtext">1934, 35mm, 24 min</span>
        <span class="avtext">George Kuchar</span>
        <strong class="avtext"><span class="avtext">Hold Me While I'm Naked</span></strong>
        <span class="avtext">1966, 16mm, 15 min</span>
      </div>
    HTML
    ver_text = Nokogiri::HTML(html).at_css("div.ver-text")
    entries = @crawler.send(:parse_short_films, ver_text)

    assert_equal 3, entries.size
    assert_equal "Karl Valentin", entries[0][:group]
    assert_equal "Im Photoatelier", entries[0][:title]
    assert_equal "1932, 35mm, 28 min", entries[0][:meta]
    assert_equal "Karl Valentin", entries[1][:group]
    assert_equal "George Kuchar", entries[2][:group]
    assert_equal "Hold Me While I'm Naked", entries[2][:title]
  end

  # ---------------------------------------------------------------------------
  # compilation detection
  # ---------------------------------------------------------------------------

  test "compilation: single film with extra strong (presenter) is not a compilation" do
    # Toy Story / Salaam Bombay case: first strong has metadata, second has presenter name
    strong_spans = [
      "Mira Nair, IN/GB/FR 1988; Drehbuch: Sooni Taraporevala. 35mm, Farbe, 114 min. Hindi mit dt. UT",
      "Tom Waibel"
    ]
    compilation = strong_spans.size > 1 && !strong_spans.first.match?(/\d{4}.*\d+\s*min/i)
    assert_equal false, compilation
  end

  test "compilation: multiple short film titles is a compilation" do
    strong_spans = [ "Studio Bankside", "Journey to Avebury", "Tarot" ]
    compilation = strong_spans.size > 1 && !strong_spans.first.match?(/\d{4}.*\d+\s*min/i)
    assert_equal true, compilation
  end

  # ---------------------------------------------------------------------------
  # format_short_films
  # ---------------------------------------------------------------------------

  test "format_short_films: ungrouped entries" do
    entries = [
      { group: nil, title: "Studio Bankside", meta: "GB 1972, 7 min" },
      { group: nil, title: "Journey to Avebury", meta: "GB 1973, 10 min" }
    ]
    result = @crawler.send(:format_short_films, entries)
    assert_includes result, "– Studio Bankside – GB 1972, 7 min"
    assert_includes result, "– Journey to Avebury – GB 1973, 10 min"
  end

  test "format_short_films: grouped entries render group headers" do
    entries = [
      { group: "Karl Valentin", title: "Im Photoatelier", meta: "1932, 28 min" },
      { group: "George Kuchar", title: "Hold Me While I'm Naked", meta: "1966, 15 min" }
    ]
    result = @crawler.send(:format_short_films, entries)
    assert_includes result, "Karl Valentin:"
    assert_includes result, "George Kuchar:"
  end

  test "format_short_films: appends description when present" do
    entries = [ { group: nil, title: "Some Film", meta: "1972, 7 min" } ]
    result = @crawler.send(:format_short_films, entries, "A long description paragraph.")
    assert_includes result, "A long description paragraph."
    assert result.index("Some Film") < result.index("A long description paragraph.")
  end

  # ---------------------------------------------------------------------------
  # parse_spielplan_meta
  # ---------------------------------------------------------------------------

  test "parse_spielplan_meta: extracts year and director from link html" do
    html = "<a><strong>Caché</strong><br/>2005, Michael Haneke</a>"
    link = Nokogiri::HTML(html).at_css("a")
    year, director = @crawler.send(:parse_spielplan_meta, link, "Caché")
    assert_equal "2005", year
    assert_equal "Michael Haneke", director
  end

  test "parse_spielplan_meta: returns year 0 and nil director when no meta" do
    html = "<a><strong>Caché</strong></a>"
    link = Nokogiri::HTML(html).at_css("a")
    year, director = @crawler.send(:parse_spielplan_meta, link, "Caché")
    assert_equal "0", year
    assert_nil director
  end
end
