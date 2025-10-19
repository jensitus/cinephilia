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
    decoded_string = decode_unicode_escapes(@to_be_normalized)
    normalized_string = I18n.transliterate(decoded_string).downcase
    return_value = normalized_string.gsub("ä", "a")
                                    .gsub("ö", "o")
                                    .gsub("ü", "u")
                                    .gsub("ß", "ss")
                                    .gsub("&", " ")
                                    .gsub(" -", "")
                                    .gsub(":", "")
                                    .gsub("'", "")
                                    .gsub(".", "")
  end

  def decode_unicode_escapes(string)
    # Replace \uXXXX with actual Unicode characters
    string.gsub(/\\u([0-9a-fA-F]{4})/) do
      [$1.hex].pack("U")
    end
  end

end
