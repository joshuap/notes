module RoamHelpers
  def block_class(block)
    case block["heading"]
    when 1
      "roam-text roam-text--heading roam-text--heading--1"
    when 2
      "roam-text roam-text--heading roam-text--heading--2"
    when 3
      "roam-text roam-text--heading roam-text--heading--3"
    else
      "roam-text roam-text--normal"
    end
  end

  def render_page_content(data, page = data)
    children = Array(data["children"])
    return "" if children.empty?

    content_tag(:ul) {
      children.map { |block|
        content_tag(:li, id: "block-#{block["uid"]}") {
          render_block(block, page) + render_page_content(block, page)
        }
      }.join
    }
  end

  def render_block(block, page)
    content_tag(:div, class: block_class(block)) {
      render_markdown(
        link_tokens(
          block["string"].to_s,
          page
        )
      ).gsub(/\(\((?<uid>[^()]+)\)\)/) {
        uid = Regexp.last_match[:uid]
        if (ref = Hash(block["outbound_block_references"])[uid])
          render_markdown(
            content_tag(:span, class: "block-ref") {
              link_to(ref["string"], "/#{string_to_slug(ref["page_title"])}#block-#{uid}", data: {prefetch: true})
            }
          )
        else
          "((#{uid}))"
        end
      }.gsub(/\^\^(?<text>[^\^]+)\^\^/) {
        content_tag(:span, Regexp.last_match[:text], class: "roam-highlight")
      }.delete("```") # RedCarpet leaves the trailing ``` from Roam when code blocks don't end in a new line.
    }
  end

  def link_tokens(string, page)
    refs = Hash(page["outbound_page_references"])
    return string unless refs.any?

    string = string.dup

    refs.each_pair do |title, page|
      string.gsub!(/(?<!#)\[\[#{Regexp.escape(title)}\]\]/, %(<span class="page-ref"><a data-prefetch="true" href="/#{string_to_slug(title)}">[[#{title}]]</a></span>))
      string.gsub!(/#\[\[#{Regexp.escape(title)}\]\]/, %(<span class="page-tag"><a data-prefetch="true" href="/#{string_to_slug(title)}">#[[#{title}]]</a></span>))
      string.gsub!(/(?<=\s)#(?!\[)#{Regexp.escape(title)}/, %(<span class="page-tag"><a data-prefetch="true" href="/#{string_to_slug(title)}">##{title}</a></span>))
    end

    string.gsub!(/(?<name>[\w\s]+)::\s/) { |_match| %(<span class="page-metadata">#{$1}:</span> ) }

    string
  end

  def string_to_slug(string)
    string.parameterize
  end

  def render_markdown(string)
    return string unless /\S/.match?(string)
    Tilt["markdown"].new(context: @app, fenced_code_blocks: true, autolink: true, hard_wrap: true) { string }.render
  end

  def has_content?(block)
    Array(block["children"]).each do |child|
      return true if child["string"].present? || has_content?(child)
    end

    false
  end

  def daily_notes
    sitemap
      .resources
      .select { |r|
        r.data[:type] == :roam_daily_note &&
          has_content?(r.data[:page])
      }
      .sort { |a, b| b.data[:date] <=> a.data[:date] }
  end
end
