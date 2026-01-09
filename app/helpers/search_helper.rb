module SearchHelper
  def highlight_search_term(text, query, options = {})
    return text if query.blank? || text.blank?

    length = options[:length] || 150
    padding = options[:padding] || 50  # Characters to show around match

    # Find the position of the first match
    first_match_pos = nil
    query.split.each do |word|
      pos = text.downcase.index(word.downcase)
      if pos && (first_match_pos.nil? || pos < first_match_pos)
        first_match_pos = pos
      end
    end

    # If we found a match and text is longer than limit
    if first_match_pos && text.length > length
      # Calculate start position to center the match
      start_pos = [ 0, first_match_pos - padding ].max
      end_pos = [ start_pos + length, text.length ].min

      # Adjust to word boundaries
      if start_pos > 0
        space_before = text.rindex(" ", start_pos + 20)
        start_pos = space_before + 1 if space_before && space_before >= start_pos - 10
      end

      if end_pos < text.length
        space_after = text.index(" ", end_pos - 20)
        end_pos = space_after if space_after && space_after <= end_pos + 10
      end

      truncated = text[start_pos...end_pos]

      # Add ellipsis
      truncated = "..." + truncated if start_pos > 0
      truncated = truncated + "..." if end_pos < text.length

      text = truncated
    elsif text.length > length
      # No match found, just truncate from beginning
      text = text[0...length] + "..."
    end

    # Highlight each word in the query
    query.split.each do |word|
      text = text.gsub(/(#{Regexp.escape(word)})/i, '<mark>\1</mark>')
    end

    text.html_safe
  end
end
