class Exam < ApplicationRecord
  has_many :questions, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :exam
  has_many :answer_books, -> { order(created_at: :desc) }, dependent: :destroy

  # Blank form rows still carry a hidden position, so ignore it when deciding a row is empty.
  accepts_nested_attributes_for :questions, allow_destroy: true,
                                reject_if: ->(attrs) { attrs.except("position", "_destroy").values.all?(&:blank?) }

  validates :title, presence: true

  def total_marks
    questions.sum(&:max_marks)
  end
end
