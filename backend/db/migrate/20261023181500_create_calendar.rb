class CreateCalendar < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :coloc, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :title, null: false
      t.text :notes
      t.boolean :all_day, null: false, default: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :recurrence, null: false, default: "none"
      t.integer :weekdays, null: false, default: 0
      t.date :until_on
      t.references :replaces_event, foreign_key: { to_table: :events }
      t.date :replaces_on

      t.timestamps
    end

    create_table :event_cancellations do |t|
      t.references :event, null: false, foreign_key: true
      t.date :occurrence_on, null: false

      t.timestamps
    end
    add_index :event_cancellations, [ :event_id, :occurrence_on ], unique: true

    create_table :rotations do |t|
      t.references :coloc, null: false, foreign_key: true
      t.string :title, null: false
      t.date :anchor_on, null: false

      t.timestamps
    end

    create_table :rotation_members do |t|
      t.references :rotation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end
    add_index :rotation_members, [ :rotation_id, :user_id ], unique: true
    add_index :rotation_members, [ :rotation_id, :position ], unique: true
  end
end
