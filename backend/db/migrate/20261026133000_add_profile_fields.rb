class AddProfileFields < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :description, :text
    add_column :users, :mood, :string
    add_column :users, :pronouns, :string
    add_column :memberships, :arrived_on, :date

    execute "UPDATE memberships SET arrived_on = date(created_at)"
    change_column_null :memberships, :arrived_on, false
  end

  def down
    remove_column :memberships, :arrived_on
    remove_column :users, :pronouns
    remove_column :users, :mood
    remove_column :users, :description
  end
end
