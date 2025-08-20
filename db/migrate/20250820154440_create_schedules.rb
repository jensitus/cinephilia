class CreateSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :schedules do |t|
      t.datetime :time
      t.boolean :three_d
      t.boolean :ov
      t.string :info
      t.bigint :movie_id
      t.bigint :cinema_id
      t.string :schedule_id

      t.timestamps
    end
    add_index :schedules, [:time, :movie_id, :cinema_id], unique: true
    add_index :schedules, :cinema_id
    add_index :schedules, :movie_id
  end
end
