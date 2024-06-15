class CreateProfessionals < ActiveRecord::Migration[7.0]
  def change
    create_table :professionals do |t|
      t.string :name
      t.string :token
      t.string :phone
      t.string :email

      t.timestamps
    end
  end
end
