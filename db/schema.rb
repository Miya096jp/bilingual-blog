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

ActiveRecord::Schema[8.0].define(version: 2025_12_11_040119) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "article_tags", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "tag_id"], name: "index_article_tags_on_article_id_and_tag_id", unique: true
    t.index ["article_id"], name: "index_article_tags_on_article_id"
    t.index ["tag_id"], name: "index_article_tags_on_tag_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.string "locale", default: "ja", null: false
    t.integer "original_article_id"
    t.integer "status", default: 0
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.bigint "user_id", null: false
    t.index ["category_id"], name: "index_articles_on_category_id"
    t.index ["original_article_id"], name: "index_articles_on_original_article_id"
    t.index ["published_at"], name: "index_articles_on_published_at"
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "blog_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "blog_title_ja"
    t.string "blog_subtitle_ja"
    t.string "theme_color", default: "blue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "blog_title_en"
    t.string "blog_subtitle_en"
    t.index ["user_id"], name: "index_blog_settings_on_user_id", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "locale", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["locale"], name: "index_categories_on_locale"
    t.index ["name", "locale"], name: "index_categories_on_name_and_locale", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.string "author_name", null: false
    t.text "content", null: false
    t.string "website"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_comments_on_article_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["name", "user_id"], name: "index_tags_on_name_and_user_id", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "username", null: false
    t.string "website"
    t.string "twitter_handle"
    t.string "facebook_handle"
    t.string "linkedin_handle"
    t.string "nickname_ja"
    t.string "nickname_en"
    t.text "bio_ja"
    t.text "bio_en"
    t.string "location_ja"
    t.string "location_en"
    t.string "github_handle"
    t.string "qiita_handle"
    t.string "zenn_handle"
    t.string "hatena_handle"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "article_tags", "articles"
  add_foreign_key "article_tags", "tags"
  add_foreign_key "articles", "articles", column: "original_article_id", on_delete: :cascade
  add_foreign_key "articles", "categories"
  add_foreign_key "articles", "users"
  add_foreign_key "blog_settings", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "comments", "articles"
  add_foreign_key "tags", "users"
end
