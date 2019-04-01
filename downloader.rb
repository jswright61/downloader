require 'ox'
require 'pry'
require 'open-uri'
require 'yaml'

class Downloader
  attr_accessor :jsw_skip_pry, :base_url
  if File.exist?('config/settings.yml')
    SETTINGS = YAML.load_file('config/settings.yml')
  else
    SETTINGS = { 'base_url': ''}
  end

  def initialize(base_url = nil)
    # when I put a binding.pry statement in code I always add a conditional
    # binding.pry unless @jsw_skip_pry
    # Yes I know I can skip remaining pry statements but I always had to look it up
    # So I adopted this convention a long time ago and I use it because it works well
    @jsw_skip_pry = false


    @base_url = base_url || SETTINGS['base_url']
  end

  def delete_files(file_pattern,skip = 67)
    # this deletes files matching the path and pattern in the file_pattern variable
    # it skips every x files defined by the skip variable
    # it's purpose is to get rid of a lot of cruft but leave some random examples

    files = Dir.glob(file_pattern)
    i = 0
    files.each do |f|
      i +=1
      if i >= skip
        i = 0
        next
      end
      File.delete(f) if File.exist?(f)
    end
  end

  def build_url_list(file_pattern = nil, force: false)
    # expects to find sitemap files in the xmls directory
    # expects the loc node of each resource to be a valid url
    # returns an array of the urls as well as writes a json file to disk

    @url_list = nil if force
    return @urls if @urls
    file_pattern ||= 'xmls/eu*.xml'
    @url_list = []
    files = Dir.glob(file_pattern)
    files.each do |f|
      h = Ox.load(File.read(f), mode: :hash_no_attrs)
      h[:urlset][:url].each { |u| @urls << u[:loc] }
    end
    @url_list.uniq!
    base_name = 'url_list_'
    suffix = '.json'
    999.times do |i|
      filename = "#{base_name}#{(i + 1).to_s.rjust(3, "0")}#{suffix}"
      next if File.exist?(filename)
      File.open(filename, 'w') { |f| JSON.pretty_generate(@url_list) }
      puts filename
      break
    end
    @url_list
  end

  def sitemap(sitemap_path = nil)
    sitemap_path ||= 'sitemap-index.xml'
    open("#{@base_url}/#{sitemap_path}").read
  end

  def sitemap_from_robots
    r_text = open("#{@base_url}/robots.txt").read.match(/sitemap:\s*(.*)\s*$/i).to_a[1]
  end

  def url_list(urls_filename = nil, force: false)
    # reads urls_filename and loads it into a variable
    @url_list = nil if force
    return @url_list if @url_list
    urls_filename = Dir.glob("url_list_???.json").last
    binding.pry unless @jsw_skip_pry
    @url_list = JSON.parse(File.read(urls_filename))
  end

  def download_files(files_to_download, dest_dir)
    # expects array of files_to_download
    # downloads each url and writes the contents to the dest_dir

    files_to_download.each do |ftd|
      filename = ftd.split('/').last
      open("#{dest_dir}/#{filename}", 'wb') { |f| f << open(ftd).read }
    end
  end

  def count_files(dir)
    Dir.glob("#{dir}/*").count
  end

  def download_docs
    urls.each do |u|
      filename = u.split('/').last.sub('.pdf', '')
      open("htmls/#{filename}", 'wb') { |f| f << open("#{@base_url}#{filename}").read }
    end
  end

end
