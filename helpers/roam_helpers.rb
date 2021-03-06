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

  def render_page_content(block, page = block)
    children = Array(block["children"])
    return "" if children.empty?

    children.map { |block|
      if block["heading"]
        render_block(block, page) + render_page_content(block, page)
      else
        render_block(block, page) + render_list(block, page)
      end
    }.join.html_safe
  end

  def render_list(block, page)
    children = Array(block["children"])
    return "" if children.empty?

    content_tag(:ul) {
      children.map { |block|
        content_tag(:li) {
          render_block(block, page) + render_list(block, page)
        }
      }.join
    }
  end

  def render_block(block, page)
    content = if block["heading"].present?
      render_heading(block)
    else
      inner_content = link_refs(
        block["string"].to_s,
        page
      ).gsub(/\A(?<name>[\w\s]+)::/) { |_match|
        %(<span class="page-metadata">#{$1}:</span>)
      }.gsub(/(?<!\s)```$/) { |_match|
        %(\n```\n) # Add newline before/after terminating code blocks
      }

      if block["permalink"].present?
        inner_content << link_to("#", block["permalink"], class: "block-permalink", title: "Permalink to block")
      end

      render_markdown(inner_content)
        .gsub(/\(\((?<uid>[^()]+)\)\)/) {
          uid = Regexp.last_match[:uid]
          if (ref = Hash(block["outbound_block_references"])[uid])
            content_tag(:span, class: "block-ref") {
              link_to(render_markdown(ref["string"], no_links: true).gsub(/<\/?p>/, ""), "/#{string_to_slug(ref["page_title"])}#block-#{uid}", data: {prefetch: true})
            }
          else
            "((#{uid}))"
          end
        }.gsub(/\^\^(?<text>[^\^]+)\^\^/) {
          content_tag(:span, Regexp.last_match[:text], class: "roam-highlight")
        }
    end

    content << yield if block_given?

    content_tag(:div, id: "block-#{block["uid"]}", class: block_class(block)) {
      content
    }
  end

  def render_heading(block)
    content = case block["heading"]
    when 1
      if block["permalink"].present?
        link_to(block["string"], block["permalink"])
      else
        block["string"]
      end
    else
      block["string"]
    end

    if block["permalink"].present?
      content << link_to("#", block["permalink"], class: "block-permalink", title: "Permalink to block")
    end

    content_tag(:p, content)
  end

  def link_refs(string, page)
    refs = Hash(page["outbound_page_references"])
    return string unless refs.any?

    string = string.dup

    refs.each_pair do |title, page|
      string.gsub!(/(?<!#)\[\[#{Regexp.escape(title)}\]\]/, %(<span class="page-ref"><a data-prefetch="true" href="/#{string_to_slug(title)}">#{title}</a></span>))
      string.gsub!(/#\[\[#{Regexp.escape(title)}\]\]/, %(<span class="page-tag"><a data-prefetch="true" href="/#{string_to_slug(title)}">##{title}</a></span>))
      string.gsub!(/(?<=\s)#(?!\[)#{Regexp.escape(title)}/, %(<span class="page-tag"><a data-prefetch="true" href="/#{string_to_slug(title)}">##{title}</a></span>))
    end

    string
  end

  def string_to_slug(string)
    string.parameterize
  end

  def render_markdown(string, no_links: false)
    return string unless /\S/.match?(string)
    Tilt["markdown"].new(context: @app, fenced_code_blocks: true, autolink: true, hard_wrap: true, no_links: no_links) { string }.render
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
