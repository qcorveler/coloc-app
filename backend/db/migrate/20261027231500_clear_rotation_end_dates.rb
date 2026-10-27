class ClearRotationEndDates < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE rotations SET ends_on = NULL"
  end

  def down
  end
end
