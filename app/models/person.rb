class Person < ApplicationRecord
  has_many :credits, dependent: :destroy
  has_many :movies, through: :credits

  validates :name, presence: true

  def acting_credits
    credits.where(role: "cast")
  end

  def directing_credits
    credits.where(role: "crew", job: "Director")
  end
end
