class CreatePushNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false

      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true

    create_table :event_reminders do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false

      t.timestamps
    end
    add_index :event_reminders, [ :event_id, :user_id, :source ], unique: true, name: "index_event_reminders_on_event_user_and_source"

    create_table :reminder_deliveries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.date :occurrence_on, null: false

      t.timestamps
    end
    add_index :reminder_deliveries, [ :user_id, :subject_type, :subject_id, :occurrence_on ],
      unique: true,
      name: "index_reminder_deliveries_uniqueness"
  end
end
