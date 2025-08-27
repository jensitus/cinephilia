class AddOriginalTitleToMovie < ActiveRecord::Migration[8.0]
  def change
    add_column :movies, :original_title, :string
  end
end
