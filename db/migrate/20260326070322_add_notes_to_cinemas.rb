class AddNotesToCinemas < ActiveRecord::Migration[8.0]
  def change
    add_column :cinemas, :notes, :text
  end
end
