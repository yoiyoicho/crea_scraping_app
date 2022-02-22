class CreateInfos < ActiveRecord::Migration[5.2]
  def change
    create_table :infos do |t|
      t.string :title
      t.string :image_url
      t.string :shorten_url

      t.timestamps
    end
  end
end
