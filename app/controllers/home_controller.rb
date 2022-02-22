require "net/http"
require "uri"
require "json"
require "nokogiri"
require "zip"
require "fileutils"

# This is a simple example which uses rubyzip to
# recursively generate a zip file from the contents of
# a specified directory. The directory itself is not
# included in the archive, rather just its contents.
#
# Usage:
#   directory_to_zip = "/tmp/input"
#   output_file = "/tmp/out.zip"
#   zf = ZipFileGenerator.new(directory_to_zip, output_file)
#   zf.write()
class ZipFileGenerator
  # Initialize with the directory to zip and the location of the output archive.
  def initialize(input_dir, output_file)
    @input_dir = input_dir
    @output_file = output_file
  end

  # Zip the input directory.
  def write
    entries = Dir.entries(@input_dir) - %w(. ..)

    ::Zip::File.open(@output_file, ::Zip::File::CREATE) do |io|
      write_entries entries, '', io
    end
  end

  private

  # A helper method to make the recursion work.
  def write_entries(entries, path, io)
    entries.each do |e|
      zip_file_path = path == '' ? e : File.join(path, e)
      disk_file_path = File.join(@input_dir, zip_file_path)
      puts "Deflating #{disk_file_path}"

      if File.directory? disk_file_path
        recursively_deflate_directory(disk_file_path, io, zip_file_path)
      else
        put_into_archive(disk_file_path, io, zip_file_path)
      end
    end
  end

  def recursively_deflate_directory(disk_file_path, io, zip_file_path)
    io.mkdir zip_file_path
    subdir = Dir.entries(disk_file_path) - %w(. ..)
    write_entries subdir, zip_file_path, io
  end

  def put_into_archive(disk_file_path, io, zip_file_path)
    io.get_output_stream(zip_file_path) do |f|
      f.write(File.open(disk_file_path, 'rb').read)
    end
  end
end

class HomeController < ApplicationController
  def top
  end

  def get_shorten_url(url)
    uri = URI.parse("https://api-ssl.bitly.com/v4/shorten")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"

    access_token = "4c1166b12a0a2cb1ffd033d6b37982e656b667fc"
    headers = {
        "Authorization" => "Bearer #{access_token}",
        "Content-Type" => "application/json"
    }
    params = {
        long_url: url
    }

    response = http.post(uri.path, params.to_json, headers)

    return JSON.parse(response.body)["link"]
  end

  def get_info(id)
    crea_url = "https://crea.bunshun.jp/articles/-/" + id +
    "?utm_source=Line&utm_medium=social&utm_campaign=CREATopics-timeline"
    
    shorten_url = get_shorten_url(crea_url)
    
    uri = URI.parse(crea_url)
    response = Net::HTTP.get_response(uri)
    html = Nokogiri::HTML.parse(response.body)
    
    image_url = html.css('//meta[property="og:image"]/@content').to_s
    title = html.css("h1").inner_text
    
    info = {title: title, image_url: image_url, shorten_url: shorten_url}
    return info
  end
  
  def scrape

    flag = true

    stock = Stock.new()
    stock.save

    article_ids = params[:article_ids].split("\r\n")
    article_ids.each do |article_id|
      info_raw = get_info(article_id)
      info = Info.new(
        title: info_raw[:title],
        image_url: info_raw[:image_url],
        shorten_url: info_raw[:shorten_url],
        stock_id: stock.id
      )
      if !info.save
        flag = false
        break
      end
    end
    
    if flag
      redirect_to("/show")
    else
      flash[:notice] = "エラーが発生しました"
      stock.destroy
      redirect_to("/")
    end

  end

  def show
    @stocks = Stock.all.order(created_at: :desc)
  end

  def downlaod
    stock = Stock.find_by(id: params[:stock_id])
    
    #テキストデータと画像を保管するディレクトリのパス
    path = "public/data/#{stock.id.to_s}/"

    #フォルダが存在しないとき、フォルダを作成し、テキストと画像をダウンロード
    if !FileTest.exist?(path)
      
      FileUtils.mkdir_p(path)

      txt_filename = path + "info.txt"
      File.open(txt_filename, "w") do |txtfile|
        stock.infos.each do |info|
        
          #テキストデータ書き込み
          txt = info.title + " 記事を読む▶︎" + info.shorten_url
          txtfile.puts(txt)

          #画像ダウンロード
          url = info.image_url
          uri = URI.parse(url)
          image = Net::HTTP.get_response(uri).body
          image_filename = open( path + info.title.slice(0..10) + ".jpg", "wb")
          image_filename.write(image)
          image_filename.close()
        end
      end
    end

    #zipファイルにしてダウンロード
    zip_filename = path + stock.id.to_s + ".zip"
    if !FileTest.exist?(zip_filename)
      zip_file_generator = ZipFileGenerator.new(path, zip_filename)
      zip_file_generator.write
    end

    # 送信
    send_file(zip_filename, type: "application/force-download")
  end

  def destroy
    
    #データベースの削除
    stock = Stock.find_by(id: params[:stock_id])
    stock_path = "public/data/#{stock.id.to_s}/"
    stock.destroy

    #実データの削除
    if FileTest.exist?(stock_path)
      FileUtils.rm_r(stock_path)
    end

    redirect_to("/show")
  end
end
