# frozen_string_literal: true

module Pipeline
  # Step 5 (Muse Spark, high reasoning): an independent "moderator" agent.
  # It looks at the original page images again, checks the transcripts were read
  # correctly, re-marks every answer, and agrees / adjusts / flags for a human.
  # Disagreement or low confidence routes the answer to teacher review.
  class Moderator < Base
    INSTRUCTIONS = <<~TXT
      You are the moderator (second examiner) for an Indian university exam. Another examiner has
      already transcribed and marked this answer book. Your job is to verify their work, independently.

      For each question:
      1. Compare the transcript with the handwriting in the page images. Note any misreading that changes the marks.
      2. Re-mark the answer yourself using the rubric (steps of 0.5, never above the maximum).
      3. verdict:
         - "agree": your marks are within 0.5 of the first examiner's and the transcript is fine.
         - "adjusted": you are confident a different mark is correct (explain why in reason).
         - "flag": a human teacher must decide (illegible key parts, ambiguous answer, diagram needs judging,
           answer looks copied, or the question number could not be matched reliably).
      Be fair to the student: do not deduct for language choice (Hindi/English) or spelling.
    TXT

    def call
      answers = book.answers.includes(:question).to_a
      return if answers.empty?

      model = self.class.moderator_model
      begin
        run(model, answers)
      rescue MetaApi::Error => e
        raise if model == "muse-spark-1.3"

        # e.g. MODERATOR_MODEL=muse-wonder-1.0 not available for images → fall back.
        Rails.logger.warn("[ExamEval] moderator #{model} failed (#{e.message}); retrying with muse-spark-1.3")
        run("muse-spark-1.3", answers)
      end
    end

    private

    def schema(numbers)
      {
        type: "object",
        additionalProperties: false,
        required: %w[reviews overall_note],
        properties: {
          reviews: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: %w[question_number transcript_ok transcript_issues marks verdict reason],
              properties: {
                question_number: { type: "string", enum: numbers },
                transcript_ok: { type: "boolean" },
                transcript_issues: { type: "string" },
                marks: { type: "number" },
                verdict: { type: "string", enum: %w[agree adjusted flag] },
                reason: { type: "string" }
              }
            }
          },
          overall_note: { type: "string" }
        }
      }
    end

    def run(model, answers)
      dossier = answers.map do |a|
        q = a.question
        <<~TXT
          ### Question #{q.number} (max #{q.max_marks.to_f})
          Question: #{q.prompt}
          Model answer: #{q.model_answer.presence || '(not provided)'}
          Rubric: #{q.rubric.presence || '(not provided)'}
          Transcript: #{a.transcript.presence || '(not attempted)'}
          First examiner: #{a.grader_marks.to_f} marks. Justification: #{a.grader_justification}
          Criteria: #{a.criteria.map { |c| "#{c['criterion']}=#{c['awarded']}/#{c['max']}" }.join('; ')}
        TXT
      end.join("\n")

      parts = [MetaApi::Client.text_part("Answer book: #{book.student_label}\n\n#{dossier}\n\nThe original pages follow in order.")]
      book.pages.first(20).each { |page| parts << MetaApi::Client.image_part(page_data_url(page)) }

      numbers = answers.map { |a| a.question.number }
      trace("moderate", model: model, summary: "#{answers.size} answer(s), #{book.pages.size} page(s)") do
        r = client.respond(model: model, instructions: INSTRUCTIONS,
                           input: [{ type: "message", role: "user", content: parts }],
                           schema: schema(numbers), schema_name: "moderation", reasoning: "high")
        reviews = Array(r.json["reviews"]).index_by { |rv| rv["question_number"].to_s }
        counts = Hash.new(0)
        answers.each do |a|
          rv = reviews[a.question.number]
          apply(a, rv)
          counts[a.moderator_verdict] += 1
        end
        book.update!(moderator_note: r.json["overall_note"])
        [r, counts.map { |k, v| "#{v} #{k}" }.join(", ")]
      end
    end

    def apply(answer, review)
      max = answer.question.max_marks
      reasons = []
      if review
        mod_marks = self.class.half_step(review["marks"], max)
        verdict = review["verdict"]
        notes = [review["reason"], (review["transcript_ok"] ? nil : "Transcript issue: #{review['transcript_issues']}")].compact.join(" ")
      else
        mod_marks = answer.grader_marks
        verdict = "flag"
        notes = "Moderator did not return a review for this question."
      end

      reasons << "Moderator flagged for teacher" if verdict == "flag"
      reasons << "Examiners disagree by #{(mod_marks.to_f - answer.grader_marks.to_f).abs}" if (mod_marks.to_f - answer.grader_marks.to_f).abs >= 1.0
      reasons << "Low handwriting legibility" if answer.reading_confidence.to_f < 0.6 && answer.transcript.present?
      reasons << "Low grading confidence" if answer.grader_confidence.to_f < 0.6
      reasons << "Transcript may be misread" if review && review["transcript_ok"] == false

      answer.update!(
        moderator_marks: mod_marks,
        moderator_verdict: verdict,
        moderator_notes: notes,
        ai_marks: verdict == "adjusted" ? mod_marks : answer.grader_marks,
        needs_review: reasons.any?,
        review_reasons: reasons.join("; ")
      )
    end
  end
end
