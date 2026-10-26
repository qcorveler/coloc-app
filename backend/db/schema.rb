# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_26_133000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "colocs", force: :cascade do |t|
    t.string "name", null: false
    t.string "address", null: false
    t.text "description"
    t.string "invite_token", null: false
    t.integer "memberships_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_token"], name: "index_colocs_on_invite_token", unique: true
  end

  create_table "event_cancellations", force: :cascade do |t|
    t.integer "event_id", null: false
    t.date "occurrence_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "occurrence_on"], name: "index_event_cancellations_on_event_id_and_occurrence_on", unique: true
    t.index ["event_id"], name: "index_event_cancellations_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "coloc_id", null: false
    t.integer "created_by_id"
    t.string "title", null: false
    t.text "notes"
    t.boolean "all_day", default: false, null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "recurrence", default: "none", null: false
    t.integer "weekdays", default: 0, null: false
    t.date "until_on"
    t.integer "replaces_event_id"
    t.date "replaces_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coloc_id"], name: "index_events_on_coloc_id"
    t.index ["created_by_id"], name: "index_events_on_created_by_id"
    t.index ["replaces_event_id"], name: "index_events_on_replaces_event_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "coloc_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "arrived_on", null: false
    t.index ["coloc_id"], name: "index_memberships_on_coloc_id"
    t.index ["user_id", "coloc_id"], name: "index_memberships_on_user_id_and_coloc_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "rotation_members", force: :cascade do |t|
    t.integer "rotation_id", null: false
    t.integer "user_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rotation_id", "position"], name: "index_rotation_members_on_rotation_id_and_position", unique: true
    t.index ["rotation_id", "user_id"], name: "index_rotation_members_on_rotation_id_and_user_id", unique: true
    t.index ["rotation_id"], name: "index_rotation_members_on_rotation_id"
    t.index ["user_id"], name: "index_rotation_members_on_user_id"
  end

  create_table "rotations", force: :cascade do |t|
    t.integer "coloc_id", null: false
    t.string "title", null: false
    t.date "anchor_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coloc_id"], name: "index_rotations_on_coloc_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.date "date_of_birth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "mood"
    t.string "pronouns"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "event_cancellations", "events"
  add_foreign_key "events", "colocs"
  add_foreign_key "events", "events", column: "replaces_event_id"
  add_foreign_key "events", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "memberships", "colocs"
  add_foreign_key "memberships", "users"
  add_foreign_key "rotation_members", "rotations"
  add_foreign_key "rotation_members", "users"
  add_foreign_key "rotations", "colocs"
  add_foreign_key "sessions", "users"
end
