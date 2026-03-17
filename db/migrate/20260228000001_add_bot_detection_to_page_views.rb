class AddBotDetectionToPageViews < ActiveRecord::Migration[8.0]
  def change
    add_column :page_views, :user_agent, :string
    add_column :page_views, :is_bot, :boolean, null: false, default: false
    add_index  :page_views, :is_bot
  end
end
