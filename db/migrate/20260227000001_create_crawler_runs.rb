class CreateCrawlerRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :crawler_runs do |t|
      t.datetime :ran_at,        null: false
      t.integer  :crawler_count, null: false, default: 0
      t.jsonb    :failures,      null: false, default: []

      t.timestamps
    end

    add_index :crawler_runs, :ran_at
  end
end
