require "pry"

activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

page "/*.xml", layout: false
page "/*.json", layout: false
page "/*.txt", layout: false

set :css_dir, "/assets/stylesheets"
set :js_dir, "/assets/javascripts"
set :images_dir, "images"

activate :external_pipeline,
  name: :webpack,
  command: build? ? "./node_modules/webpack/bin/webpack.js --bail" : "./node_modules/webpack/bin/webpack.js --watch -d",
  source: ".tmp/dist",
  latency: 1

activate :directory_indexes

set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true, autolink: true

ignore "templates/*"

configure :development do
  activate :livereload
end

helpers do
  def build_time
    @build_time ||= Time.now.utc
  end
end

ROAM_DAY_REGXP = /(?<month>January|February|March|April|May|June|July|August|September|October|November|December) (?<day>[0-9]{1,2})(?:[a-z]{2})?, (?<year>[0-9]{4})/
ROAM_DB_NAME = File.basename(ENV["ROAM_URL"].to_s).presence || "roam-export.json"
ROAM_PAGES = JSON.parse(File.read(File.expand_path("../db/#{ROAM_DB_NAME}.json", __FILE__)))

PAGES_BY_TITLE = {}
BLOCKS_BY_UID = {}
PAGES_BY_UID = {}
OUTBOUND_PAGE_REFERENCES = {}
INBOUND_PAGE_REFERENCES = {}
OUTBOUND_BLOCK_REFERENCES = {}
INBOUND_BLOCK_REFERENCES = {}

# First pass: generate reference tables
ROAM_PAGES.each do |page|
  PAGES_BY_TITLE[page["title"]] = page.dup
  children = Array(page["children"]).dup
  while (child = children.pop)
    children |= Array(child["children"])
    child["page_title"] = page["title"]

    BLOCKS_BY_UID[child["uid"]] = child.dup
    PAGES_BY_UID[child["uid"]] = page.dup

    # Store page references
    [
      /\[\[(?<title>[^\[\]]+)\]\]/, # [[References]]
      /(?<=\s)#(?!\[)(?<title>\w+)/ # #Tags
    ].each do |regexp|
      child["string"].to_s.scan(regexp) do |reference|
        INBOUND_PAGE_REFERENCES[reference[0]] ||= []
        INBOUND_PAGE_REFERENCES[reference[0]].push(page["title"])

        OUTBOUND_PAGE_REFERENCES[page["title"]] ||= []
        OUTBOUND_PAGE_REFERENCES[page["title"]].push(reference[0])
      end
    end

    # Store block references
    if child["uid"]
      child["string"].to_s.scan(/\(\((?<uid>[^()]+)\)\)/) do |reference|
        INBOUND_BLOCK_REFERENCES[reference[0]] ||= {}
        INBOUND_BLOCK_REFERENCES[reference[0]][child["uid"]] = child

        OUTBOUND_BLOCK_REFERENCES[child["uid"]] ||= {}
        OUTBOUND_BLOCK_REFERENCES[child["uid"]][reference[0]] = BLOCKS_BY_UID[reference[0]]
      end
    end
  end
end

# Second pass: link references and generate pages
ROAM_PAGES.each do |page|
  # Link references
  page["inbound_page_references"] = Array(INBOUND_PAGE_REFERENCES[page["title"]]).map { |title| [title, PAGES_BY_TITLE[title]] }.to_h
  page["outbound_page_references"] = Array(OUTBOUND_PAGE_REFERENCES[page["title"]]).map { |title| [title, PAGES_BY_TITLE[title]] }.to_h

  children = Array(page["children"]).dup
  while (child = children.pop)
    children |= Array(child["children"])

    if child["uid"]
      child["inbound_block_references"] = Hash(INBOUND_BLOCK_REFERENCES[child["uid"]])
      child["outbound_block_references"] = Hash(OUTBOUND_BLOCK_REFERENCES[child["uid"]])

      # Create the dynamic block page
      proxy "/#{child["uid"].parameterize}/index.html", "templates/roam-block.html", data: {page: page, block: child}
    end
  end

  # Create the dynamic page
  slug = page["title"].parameterize
  next if slug.blank?

  data = {title: page["title"], page: page}

  if ROAM_DAY_REGXP.match?(page["title"])
    data[:type] = :roam_daily_note
    data[:date] = Date.parse(page["title"])
  else
    data[:type] = :roam_page
  end

  proxy "/#{slug}/index.html", "templates/roam-page.html", data: data
end
