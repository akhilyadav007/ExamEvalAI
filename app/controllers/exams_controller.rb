class ExamsController < ApplicationController
  before_action :set_exam, only: [:show, :edit, :update, :destroy]

  BLANK_QUESTION_ROWS = 3

  def index
    @exams = Exam.includes(:questions, :answer_books).order(created_at: :desc)
  end

  def show
    @answer_books = @exam.answer_books.includes(answers: :question)
    @accuracy = ExamAccuracy.new(@exam)
  end

  def new
    @exam = Exam.new
    add_blank_questions
  end

  def create
    @exam = Exam.new(exam_params)
    if @exam.save
      redirect_to @exam, notice: "Exam created."
    else
      add_blank_questions
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    add_blank_questions
  end

  def update
    if @exam.update(exam_params)
      redirect_to @exam, notice: "Exam updated."
    else
      add_blank_questions
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @exam.destroy
    redirect_to exams_path, notice: "Exam deleted."
  end

  private

  def set_exam
    @exam = Exam.find(params[:id])
  end

  def add_blank_questions
    next_position = @exam.questions.map(&:position).max.to_i
    BLANK_QUESTION_ROWS.times { |i| @exam.questions.build(position: next_position + i + 1) }
  end

  def exam_params
    params.require(:exam).permit(:title, :subject, :course, :instructions,
                                 questions_attributes: [:id, :number, :prompt, :model_answer, :rubric,
                                                        :max_marks, :position, :_destroy])
  end
end
