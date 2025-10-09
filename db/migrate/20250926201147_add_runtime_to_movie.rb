class AddRuntimeToMovie < ActiveRecord::Migration[8.0]
  def change
    add_column :movies, :runtime, :integer
  end
end
