class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  validate :restricted_email

  private

  def restricted_email
    if email != 'hola@enronda.com'
      errors.add(:email, 'is not authorized for this app. Please contact support')
    end
  end
end
