module StartPageHelper
  def truncate_and_link(text, options = {})
    length = options[:length] || 100
    url = options[:url] || "#"
    return text if text.size <= length unless text.nil?

    output = raw(truncate(text, length: length))
    output += link_to(" more", url, class: "more")
    output.html_safe
  end
end
