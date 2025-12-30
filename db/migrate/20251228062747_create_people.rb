class CreatePeople < ActiveRecord::Migration[8.0]
  def change
    create_table :people do |t|
      t.string :name, null: false
      t.string :tmdb_id

      t.timestamps

      t.index :tmdb_id, unique: true
      t.index :name
    end
  end
end
