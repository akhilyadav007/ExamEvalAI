class AnswersController < ApplicationController
  def update
    book = AnswerBook.find(params[:answer_book_id])
    answer = book.answers.find(params[:id])

    attrs = if params[:confirm].present?
              { teacher_marks: answer.ai_marks, teacher_note: answer_params[:teacher_note] }
            else
              answer_params
            end

    if answer.update(attrs.merge(reviewed_at: Time.current))
      redirect_to answer_book_path(book, anchor: "q-#{answer.question.number}"),
                  notice: "Q#{answer.question.number} saved."
    else
      redirect_to answer_book_path(book, anchor: "q-#{answer.question.number}"),
                  alert: "Q#{answer.question.number}: #{answer.errors.full_messages.to_sentence}"
    end
  end

  private

  def answer_params
    params.fetch(:answer, {}).permit(:teacher_marks, :teacher_note)
  end
end
