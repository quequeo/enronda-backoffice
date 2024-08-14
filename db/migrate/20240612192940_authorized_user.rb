class AuthorizedUser < ActiveRecord::Migration[7.0]
  def up
    pwd = '123456'
    User.create!(email: 'hola@enronda.com', password: pwd, password_confirmation: pwd)
  end

  def down
    User.find_by(email: 'hola@enronda.com')&.destroy
  end
end
