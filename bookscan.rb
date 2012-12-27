# -*- encoding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'ir_b'

#本棚をlsし、自分のbookscanフォルダーをlsし持っていない本をリストアップする。
#もしも、ipad3に最適化されたものがあればそれをダウンロードする。

#TODO

#ハッシュから低速tuneにかける。最大200個。
#cronで回す。


#未作成
class Book
  def initialize
    @file_name = ""
    @book_title = ""
    @type = ""
  end
end

class Downloader
  attr_reader :book2url
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
    @agent.user_agent_alias = 'Windows IE 7'

    login()
    @books_in_bs = get_books_in_bs
    @books_tuned = get_books_tuned
    @books_in_pc = get_books_in_pc
  end

  def download_books(books_id)
    @agent.pluggable_parser.default = Mechanize::Download
    books_id.each do |book|
      @agent.get('https://system.bookscan.co.jp/tunelablist.php')
      download(book)
    end
  end

  def get_books_tuned
    get_pdf_titles("https://system.bookscan.co.jp/tunelablist.php")
  end

  def get_books_in_pc
    Dir::glob(@book_folder + "/*.pdf").map{|x| File::basename(x)}
  end


  def get_books_in_bs
    @book2url={}
    begin 
      fp = open "booklist_in_bs.txt"


      hashes_old = []
      while fp.gets
        (book,url) =$_.chomp.split("\t")
        @book2url[book] = url

      end
      fp.close
    rescue
      puts "making booklist_in_bs.txt"
    end

    f = File::open("booklist_in_bs.txt", "a")

    @agent.get('https://system.bookscan.co.jp/history.php')
    links = @agent.page.links_with(:text => '書籍一覧')

    links.each do |link|
      url = "https://system.bookscan.co.jp/"+link.href

      next if @book2url.values.index(url)
      
      @agent.get(link.href)
      books_link = @agent.page.links_with(:text => /pdf/)

    
      books_link.each do |book_link|
        f.puts book_link.text+"\t"+url
        @book2url[book_link.text] = url

      end
      sleep 1

    end
    return @book2url.keys
  end

  def download_tuned_books
    #チューンされたがまだダウンロードしていないファイルをダウンロード
    books_in_pc_id = @books_in_pc.map{|b|b.split(" ")[-1]}
    books_tuned_id_ipad = @books_tuned.select{|b|b.index("ipad")}.map{|b|b.split(" ")[-1]}

    diff_id = books_tuned_id_ipad - books_in_pc_id #tuneされたが、まだdlしていないファイル郡
  
    download_books(diff_id)

  end

  def get_undownloaded_books
    #bookscanにあるが、ダウンロードしていないファイルを表示。
    book_in_pc_text = @books_in_pc.join(",")
    @undownloaded_books = []

    @books_in_bs.each do |book| 
      unless book_in_pc_text.index(book.split(" ")[-1])
        #puts book+"\t"+dl.book2url[book]
        @undownloaded_books << book

      end
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

  #未完成
 
  def tune_books
    @undownloaded_books.each do |book|
      sleep 1 

      url = @book2url[book]
      @agent.get(url)
      book_id  = book.split(" ")[-1] #261p_419905037X.pdf などの部分
      tune_link = @agent.page.links_with(:href => /#{book_id}/)[-1]
      
      @agent.get(tune_link.href)
       #TODO
      #formの送信

    end  
  end

end

dl = Downloader.new
dl.download_tuned_books
dl.get_undownloaded_books
dl.tune_books #未完成

