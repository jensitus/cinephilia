class CreateCinemas < ActiveRecord::Migration[8.0]
  def change
    create_table :cinemas do |t|
      t.string :cinema_id
      t.string :title
      t.string :county
      t.string :uri

      t.timestamps
    end
    add_index :cinemas, :cinema_id, unique: true
  end
end
