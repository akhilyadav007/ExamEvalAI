class Answer < ApplicationRecord
  VERDICTS = %w[agree adjusted flag].freeze

  belongs_to :answer_book
  belongs_to :question

  validate :teacher_marks_within_range

  def criteria      = parse_json(criteria_json)
  def grader_flags  = parse_json(grader_flags_json)
  def region_ids    = parse_json(region_ids_json)

  def final_marks
    teacher_marks || ai_marks
  end

  def reviewed?
    reviewed_at.present?
  end

  def review_reason_list
    review_reasons.to_s.split(";").map(&:strip).reject(&:blank?)
  end

  private

  def parse_json(value)
    value.present? ? Array(JSON.parse(value)) : []
  rescue JSON::ParserError
    []
  end

  def teacher_marks_within_range
    return if teacher_marks.nil?

    if teacher_marks.negative? || teacher_marks > question.max_marks
      errors.add(:teacher_marks, "must be between 0 and #{question.max_marks.to_f}")
    elsif (teacher_marks * 2) % 1 != 0
      errors.add(:teacher_marks, "must be in steps of 0.5")
    end
  end
end
