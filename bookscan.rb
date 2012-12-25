# -*- encoding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'kconv'
require 'ir_b'

#本棚をlsし、自分のbookscanフォルダーをlsし持っていない本をリストアップする。
#もしも、ipad3に最適化されたものがあればそれをダウンロードする。

#TODO
#持ってない本を、最適化する。
#最適化にはどうするか？
#どの本がどのハッシュにあるかの表から読む。

#ハッシュから低速tuneにかける。最大200個。
#cronで回す。
#ファイルがないときの処理

#未作成
class Book
  def initialize
    @file_name = ""
    @book_title = ""
    @type = ""
  end
end

class Downloader
  attr_reader :book2hash
  def initialize
    
    config={}
    fp = open "config.txt"
    while fp.gets
      line=$_.chomp.gsub(" ","")
      config[line.split(":")[0]] = line.split(":")[1]
    end

    @id = config["id"]
    @pass = config["pass"]

    @book_folder = config["bookfolder"]
    @agent = Mechanize.new

    login()
  end

  def download_books(books_id)
    @agent.pluggable_parser.default = Mechanize::Download
    books_id.each do |book|
      @agent.get('https://system.bookscan.co.jp/tunelablist.php')
      download(book)
    end
  end

  def get_book_in_bs
    get_book2hash()
    return @book2hash.keys
  end

  def get_book_tuned
    get_pdf_titles("https://system.bookscan.co.jp/tunelablist.php")
  end

  def get_book_in_pc
    Dir::glob(@book_folder + "/*.pdf").map{|x| File::basename(x)}
  end


  def get_book2hash
    fp = open "book2hash.txt"
    @book2hash={}

    hashes_old = []
    while fp.gets
      (book,hash) =$_.chomp.split("\t")
      @book2hash[book] = hash

    end
    fp.close

    f = File::open("book2hash.txt", "a")

    @agent.get('https://system.bookscan.co.jp/history.php')
    links = @agent.page.links_with(:text => '書籍一覧')
    links.each do |link|
      hash = link.href.split("hash=")[1]

      next if @book2hash.values.index(hash)
      
      @agent.get(link.href)
      books_link = @agent.page.links_with(:text => /pdf/)

    
      books_link.each do |book_link|
        f.puts book_link.text+"\t"+hash
        @book2hash[book_link.text] = hash

      end
      sleep 1

    end
  end

  #private
  def login
    @agent.get('https://system.bookscan.co.jp/login.php')
    form = @agent.page.forms[0]
    form.field_with(:name => 'email').value = @id
    form.field_with(:name => 'password').value = @pass
    form.click_button
  end

  def download(book)
    link= @agent.page.links_with(:href => /f=ipad.*#{book}/)[0]
    puts link.text
    @agent.get(link.href).save(@book_folder + "/#{link.text}")
  end

  def get_pdf_titles(url)
    @agent.get(url)
    links = @agent.page.links_with(:href => /pdf/)
    pdf_titles = []
    links.each do |link|
      pdf_titles << link.text
    end
    return pdf_titles
  end

end

dl = Downloader.new

books_in_bs = dl.get_book_in_bs
books_tuned = dl.get_book_tuned
books_in_pc = dl.get_book_in_pc


#チューンされたがまだダウンロードしていないファイルをダウンロード
books_in_pc_id = books_in_pc.map{|b|b.split(" ")[-1]}
books_tuned_id_ipad = books_tuned.select{|b|b.index("ipad")}.map{|b|b.split(" ")[-1]}

diff_id = books_tuned_id_ipad - books_in_pc_id #tuneされたが、まだdlしていないファイル郡

dl.download_books(diff_id)

#bookscanにあるが、ダウンロードしていないファイルを表示。
book_in_pc_text = books_in_pc.join(",")

books_in_bs.each do|b|
  unless book_in_pc_text.index(book.split(" ")[-1])
    puts book+"\t"+dl.book2hash[book]

  end
end
