class ProcessAnswerBookJob < ApplicationJob
  queue_as :default

  def perform(answer_book)
    Pipeline::Runner.new(answer_book).call
  rescue MetaApi::Error => e
    # Raised before the runner starts, e.g. MODEL_API_KEY missing.
    answer_book.update!(status: "failed", error_message: e.message)
  end
end
