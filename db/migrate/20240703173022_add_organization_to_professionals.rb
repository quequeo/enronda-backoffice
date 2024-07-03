class AddOrganizationToProfessionals < ActiveRecord::Migration[7.0]
  def change
    add_column :professionals, :organization, :string
  end
end
