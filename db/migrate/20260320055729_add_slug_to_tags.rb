class AddSlugToTags < ActiveRecord::Migration[8.0]
  def change
    add_column :tags, :slug, :string
    add_index :tags, :slug, unique: true

    reversible do |dir|
      dir.up do
        Tag.reset_column_information
        Tag.find_each do |tag|
          tag.update_column(:slug, Tag.slug_from_name(tag.name))
        end
      end
    end
  end
end
