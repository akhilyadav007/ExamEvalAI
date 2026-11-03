class CreateExamevalTables < ActiveRecord::Migration[8.0]
  def change
    create_table :exams do |t|
      t.string :title, null: false
      t.string :subject
      t.string :course
      t.text :instructions
      t.timestamps
    end

    create_table :questions do |t|
      t.references :exam, null: false, foreign_key: true
      t.string :number, null: false
      t.text :prompt, null: false
      t.text :model_answer
      t.text :rubric
      t.decimal :max_marks, precision: 6, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :answer_books do |t|
      t.references :exam, null: false, foreign_key: true
      t.string :student_label, null: false
      t.string :status, null: false, default: "uploaded"
      t.text :error_message
      t.text :moderator_note
      t.datetime :processed_at
      t.timestamps
    end

    create_table :pages do |t|
      t.references :answer_book, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :width
      t.integer :height
      t.text :sam_raw
      t.timestamps
    end

    create_table :regions do |t|
      t.references :page, null: false, foreign_key: true
      t.integer :label_index, null: false
      t.integer :x1
      t.integer :y1
      t.integer :x2
      t.integer :y2
      t.float :confidence
      t.string :question_number
      t.timestamps
    end

    create_table :answers do |t|
      t.references :answer_book, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.text :transcript
      t.string :detected_language
      t.float :reading_confidence
      t.text :region_ids_json

      t.decimal :grader_marks, precision: 6, scale: 2
      t.float :grader_confidence
      t.text :grader_justification
      t.text :criteria_json
      t.text :grader_flags_json

      t.decimal :moderator_marks, precision: 6, scale: 2
      t.string :moderator_verdict
      t.text :moderator_notes

      t.decimal :ai_marks, precision: 6, scale: 2
      t.boolean :needs_review, null: false, default: false
      t.text :review_reasons

      t.decimal :teacher_marks, precision: 6, scale: 2
      t.text :teacher_note
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :answers, [:answer_book_id, :question_id], unique: true

    create_table :agent_steps do |t|
      t.references :answer_book, null: false, foreign_key: true
      t.string :step, null: false
      t.string :model
      t.string :status, null: false, default: "ok"
      t.text :summary
      t.integer :duration_ms
      t.integer :input_tokens
      t.integer :output_tokens
      t.timestamps
    end
  end
end
