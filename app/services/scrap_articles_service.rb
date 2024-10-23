require 'open-uri'
require 'net/ftp'

class ScrapArticlesService
  def initialize(article_setting, driver, ftp_data)
    @article_setting = article_setting
    @driver = driver
    @ftp_data = ftp_data
  end

  def collect_news_links
    @news_links = []
    puts 'Собираем статьи...'

    articles = @driver.find_elements(:css, @article_setting[:articles_css])

    articles.each { |article| @news_links << article.find_element(:css, 'a').attribute('href') }
    @news_links
  end


  def collect_article_info(url)
    header = @driver.find_element(:css, @article_setting[:header_css]).text if @article_setting[:header_css].present?
    image = @driver.find_element(:css, @article_setting[:main_image_css]).attribute('src') if @article_setting[:main_image_css].present?
    content = @driver.find_element(:css, @article_setting[:content_css]) if @article_setting[:content_css].present?
    article_info = {}
    # так как на текущем доноре нет времени, берем текущее
    time = Time.new.strftime("%d.%m.%Y %H:%M")
    #article_info[:published_at] = time
    #article_info[:content] = content.attribute('innerHTML')
    #article_info[:author] = 'Администратор'
    #article_info[:notice] = content.attribute('innerHTML'),
    #article_info[:image_attributes] = { "src": image }

    if content.find_elements(:css, 'img').size() > 0
      content.find_elements(:css, 'img').each do |item|
        img_url = item.attribute('src')
        local_img = save_image(img_url)
        sleep(1)

        if local_img
          img_local_path = Rails.root.join("public", "images", local_img)
          img_link_from_ftp = upload_ftp_image(img_local_path, local_img)
          img_from_site = upload_image_to_site(img_link_from_ftp)

          @driver.execute_script("arguments[0].setAttribute('src','#{img_from_site}')", item)
        end
      end
    end

    collect_donor_news = {
      "article": {
        "title": header,
        "content": content.attribute('innerHTML'),
        "published_at": time,
        "author": 'Администратор',
        'notice': content.attribute('innerHTML')
      }
    }

    collect_donor_news["image_attributes"]["src"] = image if image.present?

    #article_info

    upload_article = connection_to_site(collect_donor_news, @article_setting[:articles_url])
    article_permalink = JSON.parse(upload_article.body)["permalink"]
    article_info[:title] = header
    article_info[:old_url] = url
    article_info[:new_url] = "#{@article_setting[:main_page_new_blog]}/#{article_permalink}"

    article_info
  end


  private

  def save_image(image_url)
    begin
      image_data = URI.open(image_url)
      extension = MimeMagic.by_magic(image_data).extensions.first
      if File.basename(image_url).include?('webp')
        @filename = File.basename(image_url)
      else
        @filename = "#{File.basename(image_url)}-#{rand(1..10000)}.#{extension}"
      end

      # Загружаем изображение
      File.open(Rails.root.join('public', 'images', @filename), 'wb') do |file|
        file.write(image_data.read)
        puts "Изображение успешно сохранено"
      end

      @filename
    rescue StandardError => e
      puts "Ошибка при загрузке изображения: #{e.message}"
    end
  end

  # Загружаем изображение на сервер
  def upload_ftp_image(url, filename)
    begin
      # Скачиваем файл по URL
      #file_content = URI.open(url)

      Net::FTP.open(@ftp_data[:ftp_server], @ftp_data[:ftp_login], @ftp_data[:ftp_password]) do |ftp|
        ftp.chdir(@ftp_data[:ftp_directory])
        #@filename = File.basename(url)
        #@saved_image = save_image(url, @filename)
        ftp.putbinaryfile(url, filename)
      end

      "http://#{@ftp_data[:ftp_domain]}/images/#{filename}"

    rescue Net::FTPPermError => e
      puts "Ошибка доступа: #{e.message}"
    rescue Net::FTPError => e
      puts "Ошибка FTP: #{e.message}"
    rescue StandardError => e
      puts "Произошла ошибка: #{e.message}"
    end
  end


  # Загружаем изображения из статей в файлы сайта
  def upload_image_to_site(link)
    body = {
      'file':
        {
          'src': link
        }
    }
    data = connection_to_site(body, "#{@ftp_data[:domain]}/admin/files.json")
    JSON.parse(data.body)['absolute_url']
  end

  def connection_to_site(cur_body, url)
    uri = URI.parse(url)
    header = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' }
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, header)
    request.basic_auth @ftp_data[:username], @ftp_data[:password]
    request.body = cur_body.to_json
    https.request(request)
  end
end
