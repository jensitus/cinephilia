class NormalizeAndCleanService < BaseService
  attr_reader :to_be_normalized

  def initialize(to_be_normalized)
    @to_be_normalized = to_be_normalized
  end

  def call
    normalize_and_clean
  end

  private

  def normalize_and_clean
    normalized_string = I18n.transliterate(@to_be_normalized).downcase
    normalized_string.gsub("ä", "a")
                     .gsub("ö", "o")
                     .gsub("ü", "u")
                     .gsub("ß", "ss")
                     .gsub(" -", "")
                     .gsub(":", "")
                     .gsub("'", "")
  end

end
