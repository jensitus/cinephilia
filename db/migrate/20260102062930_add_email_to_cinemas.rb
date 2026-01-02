class AddEmailToCinemas < ActiveRecord::Migration[8.0]
  def change
    add_column :cinemas, :email, :string
  end
end
