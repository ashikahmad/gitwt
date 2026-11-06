#!/usr/bin/env ruby
# Checks every link inside the built site: the page it points to exists, and so does the
# heading or element its #fragment names. External links (http:, mailto:) aren't checked.
# Plain Ruby, no gems. Usage: ruby check_links.rb <built-site-dir> <baseurl, e.g. /gitwt>
require 'cgi'
require 'pathname'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

root, baseurl = ARGV
abort 'usage: check_links.rb <built-site-dir> <baseurl>' unless root && baseurl
root = Pathname.new(root).expand_path

def ids_in(file)
  @ids ||= {}
  @ids[file] ||= File.read(file).scan(/\sid="([^"]+)"/).flatten.map { |i| CGI.unescapeHTML(i) }
end

def page_file(root, path)
  file = root.join(path.sub(%r{\A/}, ''))
  file = file.join('index.html') if path.end_with?('/') || file.directory?
  file.file? ? file : nil
end

broken = []
checked = 0
Pathname.glob(root.join('**/*.html')).each do |file|
  rel_dir = file.dirname.relative_path_from(root).to_s
  url_dir = rel_dir == '.' ? "#{baseurl}/" : "#{baseurl}/#{rel_dir}/"
  File.read(file).scan(/<a\s[^>]*?href="([^"]*)"/).flatten.each do |href|
    href = CGI.unescapeHTML(href)
    next if href.empty? || href == '#' || href.match?(/\A[a-z][a-z0-9+.-]*:/i) || href.start_with?('//')

    path, fragment = href.split('#', 2)
    target =
      if path.empty?
        file
      else
        abs = path.start_with?('/') ? path : (Pathname.new(url_dir) + path).cleanpath.to_s
        abs += '/' if path.end_with?('/') && !abs.end_with?('/')
        next unless abs.start_with?("#{baseurl}/") || abs == baseurl

        page_file(root, abs.delete_prefix(baseurl))
      end
    checked += 1
    rel = file.relative_path_from(root)
    if target.nil?
      broken << "#{rel}: #{href} (no such page)"
    elsif fragment && !fragment.empty? && !ids_in(target).include?(CGI.unescape(fragment))
      broken << "#{rel}: #{href} (no ##{fragment} there)"
    end
  end
end

abort "Broken links:\n  #{broken.uniq.join("\n  ")}" unless broken.empty?
puts "#{checked} links checked, none broken"
