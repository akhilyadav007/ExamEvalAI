class Question < ApplicationRecord
  belongs_to :exam
  has_many :answers, dependent: :destroy

  validates :number, :prompt, presence: true
  validates :max_marks, numericality: { greater_than: 0 }
end
