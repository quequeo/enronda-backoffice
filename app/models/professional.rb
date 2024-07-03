class Professional < ApplicationRecord
  validates :name, presence: true
  validates :token, presence: true
end