class ScrapReviewsService
  def initialize(driver, ftp_data)
    @driver = driver
    @ftp_data = ftp_data
  end

  def get_info
    reviews = @driver.execute_script("return Array.from(document.querySelectorAll('.jet-testimonials__item'));")
    #reviews = @driver.find_elements(:css, '.jet-testimonials__item')

    reviews.each do |item|
      random_number = rand(1..1000)
      title = item.find_element(:css, '.jet-testimonials__title').attribute('innerHTML')
      comment = item.find_element(:css, '.jet-testimonials__comment').attribute('innerHTML')
      date = item.find_element(:css, '.jet-testimonials__date').attribute('innerHTML')
      time = Time.new.strftime("%d.%m.%Y %H:%M")
      image = item.find_element(:css, '.jet-testimonials__tag-img').attribute('data-src')
      puts image

      collect_donor_news = {
        "article": {
          "title": "#{title}||#{random_number}",
          "content": "#{comment}<br>#{date}",
          "notice": "#{comment}<br>#{date}",
          "published_at": time,
          "author": 'Администратор',
          'notice': comment,
          "image_attributes": {
            "src": image
          }
        }
      }

      puts title
      connection_to_site(collect_donor_news, "#{@ftp_data[:domain]}/admin/blogs/5838512/articles.json")
    end
  end

  private

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