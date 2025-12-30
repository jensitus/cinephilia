class Credit < ApplicationRecord
  belongs_to :movie
  belongs_to :person

  validates :role, presence: true, inclusion: { in: %w[cast crew] }
  validates :person_id, uniqueness: {
    scope: [ :movie_id, :role, :job, :character ],
    message: "already has this credit for this movie"
  }
end
