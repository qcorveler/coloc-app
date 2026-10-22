class CreateColocs < ActiveRecord::Migration[8.1]
  def change
    create_table :colocs do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.text :description
      t.string :invite_token, null: false
      t.integer :memberships_count, null: false, default: 0

      t.timestamps
    end

    add_index :colocs, :invite_token, unique: true
  end
end
