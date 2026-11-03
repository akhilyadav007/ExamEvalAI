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

ActiveRecord::Schema[8.1].define(version: 2026_11_03_105054) do
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

  create_table "agent_steps", force: :cascade do |t|
    t.integer "answer_book_id", null: false
    t.string "step", null: false
    t.string "model"
    t.string "status", default: "ok", null: false
    t.text "summary"
    t.integer "duration_ms"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_book_id"], name: "index_agent_steps_on_answer_book_id"
  end

  create_table "answer_books", force: :cascade do |t|
    t.integer "exam_id", null: false
    t.string "student_label", null: false
    t.string "status", default: "uploaded", null: false
    t.text "error_message"
    t.text "moderator_note"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_id"], name: "index_answer_books_on_exam_id"
  end

  create_table "answers", force: :cascade do |t|
    t.integer "answer_book_id", null: false
    t.integer "question_id", null: false
    t.text "transcript"
    t.string "detected_language"
    t.float "reading_confidence"
    t.text "region_ids_json"
    t.decimal "grader_marks", precision: 6, scale: 2
    t.float "grader_confidence"
    t.text "grader_justification"
    t.text "criteria_json"
    t.text "grader_flags_json"
    t.decimal "moderator_marks", precision: 6, scale: 2
    t.string "moderator_verdict"
    t.text "moderator_notes"
    t.decimal "ai_marks", precision: 6, scale: 2
    t.boolean "needs_review", default: false, null: false
    t.text "review_reasons"
    t.decimal "teacher_marks", precision: 6, scale: 2
    t.text "teacher_note"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_book_id", "question_id"], name: "index_answers_on_answer_book_id_and_question_id", unique: true
    t.index ["answer_book_id"], name: "index_answers_on_answer_book_id"
    t.index ["question_id"], name: "index_answers_on_question_id"
  end

  create_table "exams", force: :cascade do |t|
    t.string "title", null: false
    t.string "subject"
    t.string "course"
    t.text "instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pages", force: :cascade do |t|
    t.integer "answer_book_id", null: false
    t.integer "number", null: false
    t.integer "width"
    t.integer "height"
    t.text "sam_raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["answer_book_id"], name: "index_pages_on_answer_book_id"
  end

  create_table "questions", force: :cascade do |t|
    t.integer "exam_id", null: false
    t.string "number", null: false
    t.text "prompt", null: false
    t.text "model_answer"
    t.text "rubric"
    t.decimal "max_marks", precision: 6, scale: 2, default: "0.0", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_id"], name: "index_questions_on_exam_id"
  end

  create_table "regions", force: :cascade do |t|
    t.integer "page_id", null: false
    t.integer "label_index", null: false
    t.integer "x1"
    t.integer "y1"
    t.integer "x2"
    t.integer "y2"
    t.float "confidence"
    t.string "question_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_id"], name: "index_regions_on_page_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_steps", "answer_books"
  add_foreign_key "answer_books", "exams"
  add_foreign_key "answers", "answer_books"
  add_foreign_key "answers", "questions"
  add_foreign_key "pages", "answer_books"
  add_foreign_key "questions", "exams"
  add_foreign_key "regions", "pages"
end
