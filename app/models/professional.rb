class Professional < ApplicationRecord
  validates :name, presence: true
  validates :token, presence: true

  after_commit :clear_cache

  private

  def clear_cache
    Rails.cache.delete('all_professionals')
  end
end
