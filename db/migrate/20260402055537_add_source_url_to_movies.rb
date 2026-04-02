class AddSourceUrlToMovies < ActiveRecord::Migration[8.0]
  def change
    add_column :movies, :source_url, :string
  end
end
