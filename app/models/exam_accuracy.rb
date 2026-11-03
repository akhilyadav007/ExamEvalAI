# How close the AI marks are to the teacher's final marks, for answers a teacher has reviewed.
class ExamAccuracy
  AGREEMENT_TOLERANCE = 0.5

  Row = Struct.new(:question, :count, :ai_avg, :teacher_avg, :mae, keyword_init: true)

  def initialize(exam)
    @exam = exam
    @answers = Answer.joins(:answer_book)
                     .where(answer_books: { exam_id: exam.id })
                     .where.not(teacher_marks: nil).where.not(ai_marks: nil)
                     .includes(:question).to_a
  end

  def any?    = @answers.any?
  def count   = @answers.size

  def agreement_rate
    return nil if @answers.empty?

    @answers.count { |a| diff(a) <= AGREEMENT_TOLERANCE }.fdiv(@answers.size)
  end

  def mean_absolute_error
    return nil if @answers.empty?

    @answers.sum { |a| diff(a) }.fdiv(@answers.size)
  end

  def per_question
    @exam.questions.map do |q|
      list = @answers.select { |a| a.question_id == q.id }
      next Row.new(question: q, count: 0) if list.empty?

      Row.new(question: q, count: list.size,
              ai_avg: list.sum { |a| a.ai_marks.to_f } / list.size,
              teacher_avg: list.sum { |a| a.teacher_marks.to_f } / list.size,
              mae: list.sum { |a| diff(a) } / list.size)
    end
  end

  private

  def diff(answer)
    (answer.ai_marks.to_f - answer.teacher_marks.to_f).abs
  end
end
