#!/usr/bin/env ruby
# Splits the usage guide (docs/usage.md, one file so it reads well on GitHub) into one
# site page per "##" section, so the docs sidebar lists the guide's own sections. Each
# command under "## Commands" becomes a child page of Commands.
#
# Links inside the guide (#some-heading) are rewritten to the page that now holds that
# heading. /docs/ becomes a short index that forwards the old single-page links, such as
# /docs/#whats-supported (printed by gitwt 0.2.0), to their new page.
#
# Plain Ruby, no gems. Usage: ruby split_guide.rb <usage.md> <site-dir>
require 'fileutils'
require 'json'
require 'pathname'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

src, site = ARGV
abort 'usage: split_guide.rb <usage.md> <site-dir>' unless src && site

Page = Struct.new(:url, :title, :lines, :nav_order, :parent, :has_children, :shift, :top_id)

# The heading id kramdown's GFM parser gives, before making repeats unique
def base_id(text)
  text.downcase.gsub(/[^\p{Word}\- \t]/u, '').tr(" \t", '-')
end

def heading(line)
  m = line.match(/\A(#+) +(.*?)\s*\z/)
  m && [m[1].size, m[2]]
end

def plain(text)
  text.delete('`')
end

# ── split ────────────────────────────────────────────────────────────────────

index = Page.new('/docs/', 'Usage guide', [], 1, nil, false, 0)
pages = [index]
current = index
commands = nil
in_code = false

File.readlines(src).each do |line|
  fence = line.start_with?('```')
  h = !in_code && heading(line)
  in_code = !in_code if fence

  if h && h[0] == 2
    title = plain(h[1])
    current = Page.new("/docs/#{base_id(h[1])}/", title, [], pages.size + 1, nil, false, 1)
    commands = current if title == 'Commands'
    pages << current
  elsif h && h[0] == 3 && commands && (current.equal?(commands) || current.parent == 'Commands')
    commands.has_children = true
    n = pages.count { |p| p.parent == 'Commands' } + 1
    current = Page.new("/docs/commands/#{base_id(h[1])}/", plain(h[1]), [], n, 'Commands', false, 2)
    pages << current
  end

  # The guide separates sections with --- lines; pages don't need them
  next if !in_code && line.strip == '---'

  current.lines << line
end

# ── where every heading ended up ─────────────────────────────────────────────

# Old ids count repeats across the whole guide (one page); new ids per page
old_seen = Hash.new(0)
moved = {} # old id => [page url, new id]
pages.each do |page|
  new_seen = Hash.new(0)
  in_code = false
  page.lines.each do |line|
    h = !in_code && heading(line)
    in_code = !in_code if line.start_with?('```')
    next unless h

    id = base_id(h[1])
    old_id = old_seen[id].zero? ? id : "#{id}-#{old_seen[id]}"
    new_id = new_seen[id].zero? ? id : "#{id}-#{new_seen[id]}"
    old_seen[id] += 1
    new_seen[id] += 1
    moved[old_id] = [page.url, new_id]
    page.top_id ||= new_id
  end
end

# A link to <url>#<id>: just the page when <id> is the page's own title
def link_to(pages, url, id)
  page = pages.find { |p| p.url == url }
  page.top_id == id ? '' : "##{id}"
end

def relative(from_url, to_url)
  rel = Pathname.new(to_url).relative_path_from(Pathname.new(from_url)).to_s
  rel == '.' ? './' : "#{rel}/"
end

# ── write ────────────────────────────────────────────────────────────────────

out = File.join(site, 'docs')
FileUtils.rm_rf(out)
missing = []

pages.each do |page|
  in_code = false
  body = page.lines.map do |line|
    if line.start_with?('```')
      in_code = !in_code
      next line
    end
    next line if in_code

    # Headings move up a level or two: the section's own heading becomes the page title
    h = heading(line)
    line = line.sub(/\A#{'#' * page.shift}/, '') if h && page.shift.positive? && h[0] > page.shift
    # The page's own title in plain text: a big code box looks odd (the id doesn't change)
    line = line.delete('`') if h && h[0] - page.shift == 1

    line = line.gsub('the [README](../README.md)', 'the [home page](../README.md)')
    line = line.gsub('](../README.md)', "](#{relative(page.url, '/')})")
    line.gsub(/\]\(#([^)\s]+)\)/) do
      target = moved[Regexp.last_match(1)]
      missing << "#{page.url}: ##{Regexp.last_match(1)}" unless target
      next Regexp.last_match(0) unless target

      url, id = target
      url == page.url ? "](##{id})" : "](#{relative(page.url, url)}#{link_to(pages, url, id)})"
    end
  end.join.strip

  front = { 'title' => page.title, 'nav_order' => page.nav_order, 'permalink' => page.url }
  front['parent'] = page.parent if page.parent
  front['has_children'] = true if page.has_children

  if page.equal?(index)
    # Forward links from when the guide was one page: /docs/#gitwt-new -> commands/gitwt-new/
    forward = moved.reject { |_, (url, _)| url == index.url }
                   .transform_values { |url, id| "#{relative(index.url, url)}#{link_to(pages, url, id)}" }
    body += <<~HTML


      <script>
        (function () {
          var moved = #{JSON.generate(forward)};
          var id = decodeURIComponent(location.hash.slice(1));
          if (moved[id]) location.replace(moved[id]);
        })();
      </script>
    HTML
  end

  path = File.join(site, page.url, 'index.md')
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{front.map { |k, v| "#{k}: #{v.is_a?(String) ? v.inspect : v}" }.join("\n").prepend("---\n")}\n---\n\n#{body}\n")
end

abort "Links to headings that don't exist:\n  #{missing.join("\n  ")}" unless missing.empty?
puts "#{pages.size} pages in #{out}"
