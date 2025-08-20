class Cinema < ApplicationRecord
  has_many :schedules
  has_many :movies, through: :schedules
  has_and_belongs_to_many :tags
end
