# frozen_string_literal: true

module Pipeline
  # Runs the full evaluation for one answer book:
  #   rasterize → segment (SAM 3.1) → read (Muse Spark) → grade (Muse Spark) → moderate (Muse Spark, high reasoning)
  class Runner
    STEPS = [
      ["rasterizing", Rasterizer],
      ["segmenting",  Segmenter],
      ["reading",     Reader],
      ["grading",     Grader],
      ["moderating",  Moderator]
    ].freeze

    def initialize(book, client: MetaApi::Client.new)
      @book = book
      @client = client
    end

    def call
      @book.reset_results!
      STEPS.each do |status, step|
        @book.update!(status: status)
        step.new(@book.reload, client: @client).call
      end
      @book.update!(status: "ready", processed_at: Time.current, error_message: nil)
    rescue StandardError => e
      Rails.logger.error("[ExamEval] answer book #{@book.id} failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
      @book.update!(status: "failed", error_message: "#{e.class.name.demodulize}: #{e.message}".truncate(1000))
    end
  end
end
