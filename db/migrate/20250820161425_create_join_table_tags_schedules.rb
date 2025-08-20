class CreateJoinTableTagsSchedules < ActiveRecord::Migration[8.0]
  def change
    create_join_table :tags, :schedules do |t|
      # t.index [:tag_id, :schedule_id]
      # t.index [:schedule_id, :tag_id]
    end
  end
end
