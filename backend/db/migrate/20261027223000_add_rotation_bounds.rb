class AddRotationBounds < ActiveRecord::Migration[8.1]
  def change
    rename_column :rotations, :anchor_on, :starts_on
    add_column :rotations, :ends_on, :date
    add_column :rotations, :turn_days, :integer, null: false, default: 7
    add_column :rotations, :offset_days, :integer, null: false, default: 0
  end
end
