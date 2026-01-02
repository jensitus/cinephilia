class AddAddressToCinemas < ActiveRecord::Migration[8.0]
  def change
    add_column :cinemas, :street, :string
    add_column :cinemas, :city, :string
    add_column :cinemas, :zip, :string
  end
end
