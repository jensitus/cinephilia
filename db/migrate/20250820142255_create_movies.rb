class CreateMovies < ActiveRecord::Migration[8.0]
  def change
    create_table :movies do |t|
      t.string :movie_id
      t.string :title
      t.text :description
      t.string :year
      t.string :countries
      t.string :poster_path
      t.string :actors
      t.string :director
      t.string :tmdb_id

      t.timestamps
    end
  end
end
