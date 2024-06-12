class CreateCalendlyOAuths < ActiveRecord::Migration[7.0]
  def change
    create_table :calendly_o_auths do |t|
      t.string :access_token
      t.string :refresh_token
      t.string :owner
      t.string :organization

      t.timestamps
    end
  end
end
