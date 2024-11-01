require 'open-uri'
require 'net/ftp'
require 'csv'


# У нас есть csv файл, в нем надо заменить в столбце все линки на изображения на линки с хостинга
class ChangeUrlService
  def initialize(driver, ftp_data)
    @driver = driver
    @ftp_data = ftp_data
  end

  def replace_link(link)
    saved_link = save_image(link)
    return unless saved_link

    img_local_path = Rails.root.join("public", "images", saved_link)
    upload_ftp_image(img_local_path, saved_link)
  end

  # Метод для замены ссылки на новую (здесь представлена заглушка)
  def change_urls
    # Пути к исходному и результирующему файлам
    file_path = 'public/gravens-test-replace.csv'
    output_file_path = 'public/output.csv'

    # Название столбца, который нужно обработать
    column_name = 'Изображения'

    # Чтение и модификация CSV файла


    first_row = CSV.read(file_path, headers: true).first
    csv_options = { headers: true, header_converters: :symbol }
    CSV.open(output_file_path, 'w', write_headers: true, headers: first_row.headers) do |csv|

      CSV.foreach(file_path, headers: true) do |row|
        # Получаем текущее значение из указанного столбца
        links = row[column_name]

        #binding.b if links.include?('https://granves-shop.ru/images/photos/medium/shop2386-2.jpg')
        row[column_name] = links.split.map {|link| replace_link(link)}

        # Проверяем наличие ссылок и заменяем их
        if links
          updated_links = links.split.map do |link|
            puts("старый линк - #{link}")
            replace_link(link)
          end.join(' ')
          row[column_name] = updated_links
        end

        # Записываем обновленную строку в новый CSV файл
        csv << row
      end
    end
  end

  private

  def save_image(image_url)
    begin
      image_data = URI.open(image_url)
      extension = MimeMagic.by_magic(image_data).extensions.first
      if File.basename(image_url).include?('webp')
        @filename = File.basename(image_url)
      else
        @filename = "#{File.basename(image_url)}-#{rand(1..1000000)}.#{extension}"
      end

      # Загружаем изображение
      File.open(Rails.root.join('public', 'images', @filename), 'wb') do |file|
        file.write(image_data.read)
        puts "Изображение успешно сохранено"
      end

      @filename
    rescue StandardError => e
      puts "Ошибка при загрузке изображения: #{e.message}"
      nil
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

      puts("url на хостинге - http://#{@ftp_data[:ftp_domain]}/images/#{filename}")

      "http://#{@ftp_data[:ftp_domain]}/images/#{filename}"

    rescue Net::FTPPermError => e
      puts "Ошибка доступа: #{e.message}"
      nil
    rescue Net::FTPError => e
      puts "Ошибка FTP: #{e.message}"
      nil
    rescue StandardError => e
      puts "Произошла ошибка: #{e.message}"
      nil
    end
  end
end