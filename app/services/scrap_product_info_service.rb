class ScrapProductInfoService
  def initialize(product_setting, product, driver)
    @product_setting = product_setting
    @product = product
    @driver = driver
  end

  def call
    product_info = {}

    begin
      # общая проверкна наличия элемента
      def element_present?(selector)
        selector.present? && @driver.find_elements(:css, selector).any?
      end

      # собираем название
      if element_present?(@product_setting[:product_name])
        name = @driver.find_element(:css, @product_setting[:product_name].to_s).text
        product_info['Название товара или услуги'] = name.gsub(';',',')
        puts("Собираем информацию товара.Текущий - #{name}")
      else
        product_info['Название товара или услуги'] = ''
      end

      # собираем цену
      unless element_present?(@product_setting[:options_container]) && @product_setting[:product_price_from_variant].present?
        if element_present?(@product_setting[:product_price])
          price = @driver.find_element(:css, @product_setting[:product_price]).text.gsub(/[^\d,\.]/, '')
          product_info['Цена продажи'] = price
          puts("Цена продажи - #{price}")
        else
          product_info['Цена продажи'] = ''
        end
      end

      # собираем старую цену
      if element_present?(@product_setting[:old_price])
        price = @driver.find_element(:css, @product_setting[:old_price]).text.gsub(/[^\d,\.]/, '')
        product_info['Старая цена'] = price
        puts("Старая цена - #{price}")

      end

      # собираем артикул
      if element_present?(@product_setting[:product_sku])
        sku = @driver.find_element(:css, @product_setting[:product_sku]).text

        puts("Артикул - #{sku}")
        product_info['Артикул'] = sku.gsub(';',',')
      end

      # собираем старый урл
      #old_url = @driver.current_url
      #product_info['old_url'] = old_url

      # собираем параметры.
      if element_present?(@product_setting[:properties_block])
        properties_block = @driver.find_element(:css, @product_setting[:properties_block])
        # Так как параметры скрыты при загрузке страницы, делаем их видимыми
        @driver.execute_script('arguments[0].style.display = "block"', properties_block)
        if element_present?(@product_setting[:property])
          properties = properties_block.find_elements(:css, @product_setting[:property])
          props_values = []
          prop_title = ''

          properties.each do |prop|
            prop_title = prop.find_element(:css, @product_setting[:prop_title]).text rescue next
            #prop_value = prop.find_element(:css, @product_setting[:prop_value]).text rescue next
            prop.find_elements(:css, @product_setting[:prop_value]).each do |value|
              props_values << value.text.gsub(';',',') if value.text != ' ' rescue next
            end
          end
          product_info["Параметр: #{prop_title}"] = props_values.join('##')
        end
      end

      # собираем дополнительные поля.
      if element_present?(@product_setting[:fields_container])
        fields_block = @driver.find_element(:css, @product_setting[:fields_container])

        if element_present?(@product_setting[:single_field])
          fields = fields_block.find_elements(:css, @product_setting[:single_field])

          fields.each do |field|
            field_value = field.find_element(:css, @product_setting[:field_value]) rescue next
            # Так как поля скрыты при загрузке страницы, делаем их видимыми
            @driver.execute_script('arguments[0].style.display = "block"', field_value)
            field_title = field.find_element(:css, @product_setting[:field_title]).text rescue next
            puts("Дополнительне поле - #{field_title}")

            product_info["Дополнительне поле: #{field_title.gsub(';',',')}"] = field_value.text.gsub(';',',')
          end
        end
      end

      #  Собираем изображения
      if element_present?(@product_setting[:product_images])
        images = @driver.find_elements(:css, @product_setting[:product_images])
        all_images = images.map { |img| img.attribute(@product_setting[:product_images_type]) }
        puts("Изобаржения - #{all_images.join(', ')}")
        product_info['Изображения'] = all_images.join(', ')
      end

      # Добавляем к данным категорию и старый адрес
      @product.each do |product, details|
        #category_value = if element_present?(@product_setting[:fields_container])
          #@driver.find_element(:css, @product_setting[:product_category]).text
        #else
          #details[:category]&.map { |cat| "Каталог/#{cat}" }&.join('##')
        #end
        #

        product_info["Размещение на сайте"] =  details[:category].join('##').gsub(';',',')
        puts("Размещение на сайте - #{details[:category]}")
        product_info["old url"] = details[:url] if details[:url]&.present?
      end


      # собираем краткое описание
      if element_present?(@product_setting[:product_short_description])
        short_description = @driver.find_element(:css, @product_setting[:product_short_description]).attribute('innerHTML')
        puts("Краткуое описание - #{short_description}")
        product_info['Краткое описание'] = short_description.gsub(';',',')
      end

      # собираем описание
      if element_present?(@product_setting[:product_description])
        description = @driver.find_element(:css, @product_setting[:product_description]).attribute('innerHTML')
        product_info['Полное описание'] = description.gsub(';',',')
      end

      if element_present?(@product_setting[:options_container])
        all_variants = []
        options = @driver.find_elements(:css, @product_setting[:options_container])

        options.each do |option|
          if element_present?(@product_setting[:options_value])
            title = option.find_element(:css, @product_setting[:options_title]).text rescue next
            variants = option.find_elements(:css, @product_setting[:options_value])

            variants.each do |item|
              new_variant = product_info.dup
              if element_present?(@product_setting[:product_price_from_variant])
                item_title, item_value = item.text.split(@product_setting[:product_price_from_variant])

                new_variant['Цена продажи'] = item_value
              else
                item_title = item.text
              end

              new_variant["Свойство:#{title}"] = item_title.gsub(';',',')
              all_variants << new_variant
            end
          end
        end
        all_variants
      else
        product_info
      end

    # Todo добавить нормальную обработку ошибок
    rescue Selenium::WebDriver::Error::NoSuchElementError => e
      puts "Элемент не найден: #{e.message}"
      product_info
    rescue Net::ReadTimeout => e
      puts "Ошибка сети (тайм-аут): #{e.message}"
      product_info
    rescue StandardError => e
      puts "Общая ошибка: #{e.message}"
      product_info
    end
  end
end
