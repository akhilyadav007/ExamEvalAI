class AnswerBook < ApplicationRecord
  STATUSES = %w[uploaded rasterizing segmenting reading grading moderating ready failed].freeze
  PROCESSING = %w[uploaded rasterizing segmenting reading grading moderating].freeze

  belongs_to :exam
  has_many_attached :uploads
  has_many :pages, -> { order(:number) }, dependent: :destroy
  has_many :answers, dependent: :destroy
  has_many :agent_steps, -> { order(:id) }, dependent: :destroy

  validates :student_label, presence: true
  validates :status, inclusion: { in: STATUSES }

  def reset_results!
    transaction do
      answers.destroy_all
      pages.destroy_all
      agent_steps.destroy_all
      update!(moderator_note: nil, error_message: nil, processed_at: nil)
    end
  end

  def ai_total
    answers.sum { |a| a.ai_marks.to_d }
  end

  def final_total
    answers.sum { |a| a.final_marks.to_d }
  end

  def needs_review_count
    answers.count { |a| a.needs_review? && a.teacher_marks.nil? }
  end

  def processing?
    PROCESSING.include?(status)
  end

  def ready?  = status == "ready"
  def failed? = status == "failed"
end
