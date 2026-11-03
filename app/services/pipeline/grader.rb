# frozen_string_literal: true

module Pipeline
  # Step 4 (Muse Spark): mark each answer against the teacher's model answer and
  # rubric, criterion by criterion, with evidence quoted from the transcript.
  class Grader < Base
    INSTRUCTIONS = <<~TXT
      You are an experienced, fair examiner for an Indian state university.
      Mark the student's answer strictly according to the rubric and model answer.

      Rules:
      - Give credit for correct content in Hindi or English equally. Ignore spelling and grammar
        unless the rubric says otherwise.
      - Award marks per rubric criterion, in steps of 0.5. Never exceed a criterion's maximum or the question maximum.
      - "evidence" must quote (or closely paraphrase) the student's words that earned the marks, or say what is missing.
      - If the transcript is empty, the question was not attempted: give 0 with confidence 1.
      - If parts are [illegible] and that affects marking, lower your confidence and add the flag "illegible".
      - Other useful flags: "off_topic", "possible_copying", "partial_attempt", "diagram_needs_check".
      - confidence (0 to 1) is how sure you are that a senior examiner would award the same marks.
      - justification: 1–3 short sentences in English for the teacher.
    TXT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[criteria marks justification confidence flags],
      properties: {
        criteria: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[criterion awarded max evidence],
            properties: {
              criterion: { type: "string" },
              awarded: { type: "number" },
              max: { type: "number" },
              evidence: { type: "string" }
            }
          }
        },
        marks: { type: "number" },
        justification: { type: "string" },
        confidence: { type: "number" },
        flags: { type: "array", items: { type: "string" } }
      }
    }.freeze

    def call
      book.answers.includes(:question).each { |answer| grade(answer) }
    end

    private

    def grade(answer)
      q = answer.question
      if answer.transcript.blank?
        answer.update!(grader_marks: 0, grader_confidence: 1.0, grader_justification: "Not attempted.",
                       criteria_json: "[]", grader_flags_json: '["not_attempted"]')
        return
      end

      prompt = <<~TXT
        Question #{q.number} (maximum #{q.max_marks.to_f} marks):
        #{q.prompt}

        Model answer:
        #{q.model_answer.presence || '(not provided)'}

        Rubric:
        #{q.rubric.presence || "(not provided — use the model answer and award marks proportionally)"}

        Student's answer (transcribed from handwriting; reader legibility #{answer.reading_confidence&.round(2)}):
        """
        #{answer.transcript}
        """
      TXT

      trace("grade", model: self.class.grader_model, summary: "Q#{q.number}") do
        r = client.respond(model: self.class.grader_model, instructions: INSTRUCTIONS,
                           input: MetaApi::Client.user_message(MetaApi::Client.text_part(prompt)),
                           schema: SCHEMA, schema_name: "grade", reasoning: "medium")
        marks = self.class.half_step(r.json["marks"], q.max_marks)
        answer.update!(
          grader_marks: marks,
          grader_confidence: r.json["confidence"].to_f.clamp(0.0, 1.0),
          grader_justification: r.json["justification"],
          criteria_json: Array(r.json["criteria"]).to_json,
          grader_flags_json: Array(r.json["flags"]).to_json
        )
        [r, "Q#{q.number}: #{marks}/#{q.max_marks.to_f} (confidence #{r.json['confidence'].to_f.round(2)})"]
      end
    end
  end
end
