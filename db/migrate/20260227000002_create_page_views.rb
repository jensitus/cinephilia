class CreatePageViews < ActiveRecord::Migration[8.0]
  def change
    create_table :page_views do |t|
      t.string   :path,          null: false
      t.string   :county
      t.string   :viewable_type
      t.bigint   :viewable_id
      t.datetime :occurred_at,   null: false
    end

    add_index :page_views, :occurred_at
    add_index :page_views, [ :viewable_type, :viewable_id ]
  end
end
