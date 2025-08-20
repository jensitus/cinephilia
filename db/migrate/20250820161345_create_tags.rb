class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :tag_id
      t.string :name

      t.timestamps
    end
  end
end
