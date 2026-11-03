class AnswerBooksController < ApplicationController
  ALLOWED_TYPES = %w[application/pdf image/jpeg image/png image/webp].freeze

  def new
    @exam = Exam.find(params[:exam_id])
    @answer_book = @exam.answer_books.build
  end

  def create
    @exam = Exam.find(params[:exam_id])
    @answer_book = @exam.answer_books.build(answer_book_params)
    files = Array(params.dig(:answer_book, :uploads)).compact_blank

    if files.empty?
      @answer_book.errors.add(:uploads, "— choose at least one PDF or image")
    elsif (bad = files.reject { |f| ALLOWED_TYPES.include?(f.content_type) }).any?
      @answer_book.errors.add(:uploads, "must be PDF, JPG or PNG (got #{bad.map(&:original_filename).join(', ')})")
    end

    if @answer_book.errors.none? && @answer_book.save
      @answer_book.uploads.attach(files)
      ProcessAnswerBookJob.perform_later(@answer_book)
      redirect_to @answer_book, notice: "Uploaded. Evaluation has started."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @answer_book = AnswerBook.includes(:exam, pages: [:regions, { image_attachment: :blob }]).find(params[:id])
    @exam = @answer_book.exam
    @answers = @answer_book.answers.includes(:question).sort_by { |a| [a.question.position, a.question.id] }
    @agent_steps = @answer_book.agent_steps
  end

  def rerun
    book = AnswerBook.find(params[:id])
    if book.processing? && book.updated_at > 15.minutes.ago
      redirect_to book, alert: "Evaluation is already running."
    else
      book.update!(status: "uploaded", error_message: nil)
      ProcessAnswerBookJob.perform_later(book)
      redirect_to book, notice: "Re-running evaluation. Teacher marks for this book will be cleared."
    end
  end

  def destroy
    book = AnswerBook.find(params[:id])
    exam = book.exam
    book.destroy
    redirect_to exam, notice: "Answer book deleted."
  end

  private

  def answer_book_params
    params.require(:answer_book).permit(:student_label)
  end
end
