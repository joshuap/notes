module RoamHelpers
  def render_page_content(data, page = data)
    children = Array(data["children"])
    return "" if children.empty?
    content_tag(:ul) do
      children.map { |block|
        content_tag(:li, id: "block-#{block["uid"]}") {
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
          } + render_page_content(block, page)
        }
      }.join
    end
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
    Tilt["markdown"].new(context: @app, fenced_code_blocks: true, autolink: true) { string }.render
  end
end
