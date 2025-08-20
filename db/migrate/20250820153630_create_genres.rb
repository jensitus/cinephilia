class CreateGenres < ActiveRecord::Migration[8.0]
  def change
    create_table :genres do |t|
      t.string :genre_id
      t.string :name

      t.timestamps
    end
    add_index :genres, :genre_id, unique: true
  end
end
