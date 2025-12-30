class CreateCredits < ActiveRecord::Migration[8.0]
  def change
    create_table :credits do |t|
      t.references :movie, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.string :role, null: false
      t.string :job
      t.string :character
      t.integer :order

      t.timestamps

      t.index [:movie_id, :person_id, :role]

      t.index [:movie_id, :person_id, :role, :job, :character],
              unique: true,
              name: 'index_credits_on_uniqueness'
    end
  end
end
