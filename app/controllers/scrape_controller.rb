require 'csv'

class ScrapeController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!

  FTP_DATA = {
    ftp_domain: 'a1020236.xsph.ru',
    ftp_server: '141.8.192.126',
    ftp_login: 'a1020236',
    ftp_password: 'f0797454',
    ftp_directory: '/domains/a1020236.xsph.ru/public_html/images',
    username: 'bcdb7394713d929b2b9a02bf59a1463d',
    password: '8ca328b694714ad859ec1096545b9731',
    domain: 'https://myshop-clu985.myinsales.ru'
  }

  ARTICLE_SETTINGS = {
    main_page: 'https://botanicafood.ru/blog/',
    articles_url: 'https://myshop-clu985.myinsales.ru//admin/blogs/5833585/articles.json',
    main_page_new_blog: 'https://myshop-cls41.myinsales.ru/blogs/blog',
    articles_css: 'article',
    header_css: '.post-title',
    main_image_css: '.post-thumbnail img',
    content_css: '.post-info',
    paginate_css: '.pagination',
    count_page: 25
  }

  def index; end

  def articles; end

  def next_page_exists?(driver)
    begin
      next_button = driver.find_element(:xpath, '//a[text()="Следующая"]') # Измените XPath в зависимости от структуры страницы
      return true if next_button.displayed?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      return false
    end
  end


  # пробуем собирать категории
  def collect_categories
    @list_categories = []
    main_page = 'https://granves-shop.ru/shop'
    new_connection = ConnectionService.new
    @products = {}
    @all_products = []
    @driver = new_connection.set_dirver
    page(main_page)

    #catalog_category_css = '.catalog-sections .catalog-sections__item .catalog-sections__title a:first-child'
    #categories = @driver.find_elements(:css, catalog_category_css,)

    # собираем категории
    # #main .pathway
    #@list_categories = scrape_categories(@driver)

    test_categories = {"Автосвет, электрика и звук": "https://granves-shop.ru/shop/osveschenie-i-yelektrika"}

    # собираем товары
    test_categories.each do |key, value|
      unless value.is_a?(Hash)
        @driver.navigate.to(value)

        loop do
          scrap_products_links(key)

          break unless next_page_exists?(@driver)

          # Нажимаем на кнопку "Следующая", чтобы перейти на следующую страницу
          next_button = @driver.find_element(:xpath, '//a[text()="Следующая"]') # Измените XPath в зависимости от структуры страницы
          next_button.click

          sleep 1 # Добавьте задержку, чтобы страница успела загрузиться
        end
      end
    end

    puts("all products - #{@products}")

    @products.each do |name, value|
      page(value[:url])
      sleep 1
      new_scrap_info = ScrapProductInfoService.new(params, { name: value }, @driver)
      product = new_scrap_info.call

      if product.is_a?(Array)
        @all_products.concat(product)
      else
        @all_products << product
      end
    end

    puts @products
  end

  def products
    #[https://pirosmani.info/mens-all,https://pirosmani.info/womens-all,https://pirosmani.info/sale-off,https://pirosmani.info/new]
    #подкатегория - .filter-options-content .mgs-ajax-layer-item
    #главная - https://pirosmani.info/
    # продукт .item.product
    # линк продукта .product-item-link
    # # name product - .product-name
    #  price -  .product-info-price .price
    @main_page = params[:main_page]
    @category_header = params[:category_header]
    @scraping_pages = params[:categories_list].split(",")
    @subcategory_css = params[:subcategory_link]
    @product_css = params[:product_css]
    @product_link_css = params[:product_link_css]
    @all_products = []
    @products = {}
    @collected_subcategories = {}
    @list_categories = []

    new_connection = ConnectionService.new
    @driver = new_connection.set_dirver
    page(@main_page)

    #@list_categories = scrape_categories(@driver)

    # #main .pathway
    test_categories = {
      "Главная → Шумоизоляция": "https://granves-shop.ru/shop/shumoizoljacija"
    }

    # собираем товары new
    test_categories.each do |key, value|
      unless value.is_a?(Hash)
        @driver.navigate.to(value)

        loop do
          scrap_products_links(key)

          break unless next_page_exists?(@driver)

          # Нажимаем на кнопку "Следующая", чтобы перейти на следующую страницу
          next_button = @driver.find_element(:xpath, '//a[text()="Следующая"]') # Измените XPath в зависимости от структуры страницы
          next_button.click

          #sleep 1 # Добавьте задержку, чтобы страница успела загрузиться
        end
      end
    end

    # собираем информацию товара
    @products.each do |name, value|
      page(value[:url])
      #sleep 1
      new_scrap_info = ScrapProductInfoService.new(params, { name: value }, @driver)
      product = new_scrap_info.call

      if product.is_a?(Array)
        @all_products.concat(product)
      else
        @all_products << product
      end
    end


    puts("Все продукты - #{@all_products}")

    write_file(@all_products, 'products')
    new_connection.close_driver(@driver)

    #respond_to do |format|
     # format.json { render json: @products_url }
    #end
  end

  def change_linlk_in_file
    @new_service = ChangeUrlService.new(@driver, FTP_DATA)
    @new_service.change_urls
  end

  def upload_articles
    new_connection = ConnectionService.new
    @driver = new_connection.set_dirver
    @articles = []
    @articles_links = []

    if params[:pagination].to_i == 1 && params[:paginate_css]
      @articles_links = []
      pages = scrape_paginate_pages

      pages.each do |page|
        page(page)
        @new_scrap_info = ScrapArticlesService.new(params, @driver, FTP_DATA)
        @articles_links.concat(@new_scrap_info.collect_news_links)
      end
    else
      page(params[:main_page])
      @new_scrap_info = ScrapArticlesService.new(params, @driver, FTP_DATA)
      @articles_links.concat(@new_scrap_info.collect_news_links)
    end


   @articles_links.each do |link|
      puts link
      page(link)
      @articles << @new_scrap_info.collect_article_info(link)
    end

    #@articles << @new_scrap_info.collect_article_info(@articles_links[0])

    write_file(@articles, "articles")

    new_connection.close_driver(@driver)
  end

  def reviews
    new_connection = ConnectionService.new
    @driver = new_connection.set_dirver
    page('https://palo-santo.ru/feedback-recomendations/')

    @new_scrap_info = ScrapReviewsService.new(@driver, FTP_DATA)
    @new_scrap_info.get_info

    new_connection.close_driver(@driver)
  end


  private

  def page(cur_page, need_dynamic_pagination = false)
    # Посещаем страницу, открытую в браузере
    retries = 0
    max_retries = 2


    begin
      @driver.navigate.to cur_page
      dynamic_paginate if need_dynamic_pagination
    rescue Net::ReadTimeout => e
      retries += 1
      if retries <= max_retries
        puts "Ошибка: #{e.message}. Попытка #{retries} из #{max_retries}..."
        sleep(30) # Задержка перед повторной попыткой
        retry
      else
        puts "Достигнуто максимальное количество попыток. Завершение."
      end

    end
  end

  def scrape_categories(driver, categories_hash = {})
    # Найти все подкатегории текущей категории
    catalog_category_css = '.catalog-sections .catalog-sections__item .catalog-sections__title a:first-child'
    categories = driver.find_elements(:css, catalog_category_css)

    return if categories.empty?
    
    categories.each_with_index do |category, index|
      #category_name = category.text
      category_link = category.attribute('href')
      
      # Сохраняем данные в хэш
      #categories_hash[category_name] = category_link unless category_name.empty?

      # Если есть ссылка, кликаем и обходим подкатегории
      if category_link
        # Открываем ссылку в новой вкладке
        driver.execute_script('window.open(arguments[0], "_blank");', category_link)
        
        # Переключаемся на новую вкладку
        driver.switch_to.window(driver.window_handles.last)
        category_name = driver.find_element(:css, '#main .pathway').text
        puts category_name
        categories_hash[category_name] = category_link unless category_name.empty?
        
        # Рекурсивно обходим подкатегории в новой вкладке
        scrape_categories(driver, categories_hash)
        
        # Закрыть вкладку и вернуться на предыдущую
        driver.close

        driver.switch_to.window(driver.window_handles.last)
        #sleep(1)
      end
    end

    write_file(categories_hash, 'categories')
    categories_hash
  end


  def dynamic_paginate
    last_height = @driver.execute_script("return document.body.scrollHeight")

    loop do
      # Прокрутка вниз
      @driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")

      # Пауза, пока загрузится страница
      sleep(2)

      # Вычисляем новую высоту прокрутки и сравниваем с последней высотой прокрутки
      new_height = @driver.execute_script("return document.body.scrollHeight")

      if new_height == last_height
        puts "Прокрутка завершена"
        break
      end

      last_height = new_height
      puts "Появился новый контент, прокручиваем дальше"
    end
  end


  def scrape_paginate_pages
    pages = []
    pages << params[:main_page]
    #params[:main_page],  params[:count_pages], params[:paginate_css]

    return unless params[:count_pages]

    last_page_number.downto(1) do |item|
      page = "#{first_page}page/#{item}/"
      page(page)
      pages << page
      puts "Собираем страницы блога - #{item}"
    end

    pages
  end

  def scrap_products_links(category_title, subcategory_title = '')
    #return puts 'Товаров с таким селектом нет' unless @driver.find_element(:css, @product_css).displayed?

    puts 'Собираем продукты...'
    # Собираем все продукты
    html_products = @driver.find_elements(:css, @product_css)
    #html_products = @driver.find_elements(:css, '.shop_unit.shop_item')

    html_products.each do |html_product|
      begin
        # Пытаемся найти элемент
        element = html_product.find_element(:css, @product_link_css)
        #element = html_product.find_element(:css, '.title a')

        # Проверяем, отображается ли элемент
        next unless element.displayed?

        # Получаем URL
        url = element&.attribute("href")
        title = element&.text

        subcategory = subcategory_title.empty? ?  "#{category_title}" : "#{category_title}/#{subcategory_title}"
        if @products.key?(title)

          @products[title][:category] << subcategory
        else

          @products[title] = { category: [ subcategory ], url: url }
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        puts 'нет товаров'
        next
      end
    end
  end

  def generate_csv(products)
    CSV.generate(headers: true) do |csv|
      csv << ["ID", "Name", "Price"] # Заголовки столбцов

      products.each do |product|
        csv << [product.id, product.name, product.price] # Данные
      end
    end
  end

  def write_file(items, type)
    puts 'Записываем в файл...'
    file_headers = []
    items.each do |item|
      item.each { |key, _| file_headers << key unless file_headers.include? key }
    end

    CSV.open(Rails.root.join('public', 'csv', "#{type}-#{Date.today}.csv"), 'wb', write_headers: true, headers: file_headers) do |csv|
      items.each do |item|
        csv << item
      end
    end
  end


  def product_params
    params.permit(:main_page, :product_css, :product_link_css, :categories_list, :subcategory_link, :category_header, :dynamic_pagination, :product_name, :product_price, :product_short_description)
  end
end
