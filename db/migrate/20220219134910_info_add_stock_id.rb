class InfoAddStockId < ActiveRecord::Migration[5.2]
  def change
    add_column :infos, :stock_id, :integer
  end
end
