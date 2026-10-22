class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :coloc, null: false, foreign_key: true

      t.timestamps
    end

    add_index :memberships, [ :user_id, :coloc_id ], unique: true
  end
end
