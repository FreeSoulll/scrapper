class CreateShops < ActiveRecord::Migration[7.2]
  def change
    create_table :shops do |t|
      t.string :shop_title, null: false
      t.string :api_token_shop
      t.string :api_token_password
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
