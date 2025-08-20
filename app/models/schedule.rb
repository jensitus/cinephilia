class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :cinema
  has_and_belongs_to_many :tags
end
