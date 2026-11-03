class Exam < ApplicationRecord
  has_many :questions, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :exam
  has_many :answer_books, -> { order(created_at: :desc) }, dependent: :destroy

  accepts_nested_attributes_for :questions, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true

  def total_marks
    questions.sum(&:max_marks)
  end
end
