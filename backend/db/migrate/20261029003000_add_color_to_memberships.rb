class AddColorToMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :memberships, :color, :string
    add_index :memberships, [ :coloc_id, :color ], unique: true

    Coloc.find_each do |coloc|
      coloc.memberships.order(:id).each_with_index do |membership, index|
        membership.update_column(:color, Membership::COLORS.fetch(index))
      end
    end

    change_column_null :memberships, :color, false
  end

  def down
    remove_index :memberships, [ :coloc_id, :color ]
    remove_column :memberships, :color
  end
end
