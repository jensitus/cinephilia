class AddIndexToMovies < ActiveRecord::Migration[8.0]
  def change
    add_index :movies, [ :movie_id ], unique: true
  end
end
