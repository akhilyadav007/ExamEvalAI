# frozen_string_literal: true

module Pipeline
  # Shared helpers for every pipeline step: API client access, model names,
  # and an agent-trace logger that records each model call for the review UI.
  class Base
    attr_reader :book, :client

    def initialize(book, client:)
      @book = book
      @client = client
    end

    def self.reader_model    = ENV.fetch("READER_MODEL", "muse-spark-1.3")
    def self.grader_model    = ENV.fetch("GRADER_MODEL", "muse-spark-1.3")
    def self.moderator_model = ENV.fetch("MODERATOR_MODEL", "muse-spark-1.3")
    def self.sam_model       = ENV.fetch("SAM_MODEL", "sam-3.1")

    private

    def exam
      book.exam
    end

    def questions
      exam.questions
    end

    def question_numbers
      questions.map(&:number)
    end

    def page_data_url(page)
      MetaApi::Client.image_data_url(page.image.download, page.image.content_type || "image/jpeg")
    end

    # Records one agent step (model call) with timing and token usage.
    def trace(step, model:, summary: nil)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      record = book.agent_steps.create!(step: step, model: model, status: "running", summary: summary)
      result, final_summary = yield
      usage = result.respond_to?(:usage) ? (result.usage || {}) : {}
      record.update!(
        status: "ok",
        summary: final_summary || summary,
        duration_ms: elapsed_ms(started),
        input_tokens: usage["input_tokens"],
        output_tokens: usage["output_tokens"]
      )
      result
    rescue StandardError => e
      record&.update!(status: "error", summary: "#{summary} — #{e.message}".strip, duration_ms: elapsed_ms(started))
      raise
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end

    # 4.0 → "4", 6.5 → "6.5" (for trace summaries)
    def self.fmt(value)
      v = value.to_f
      v == v.round ? v.round.to_s : v.to_s
    end

    def self.half_step(value, max)
      v = (value.to_f * 2).round / 2.0
      v.clamp(0.0, max.to_f)
    end
  end
end
