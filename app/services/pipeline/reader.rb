# frozen_string_literal: true

module Pipeline
  # Step 3 (Muse Spark vision): read each page, decide which question every
  # answer block belongs to, and transcribe the handwriting verbatim
  # (Hindi in Devanagari, English as written, mixed scripts kept as is).
  class Reader < Base
    INSTRUCTIONS = <<~TXT
      You are a careful exam-script reader for an Indian university. You read photographed or
      scanned handwritten answer books written in Hindi (Devanagari), English, or a mix of both.

      Rules:
      - Transcribe EXACTLY what the student wrote. Do not fix spelling, grammar or facts.
        Keep Hindi in Devanagari and English in Latin script. Keep the student's line order.
      - Describe diagrams, tables or crossed-out text briefly in square brackets, e.g. [diagram: water cycle with labels].
      - Use [illegible] for words you cannot read. Never guess silently.
      - Assign each answer to one of the allowed question numbers. Students write markers like
        "Q1", "1.", "प्रश्न 1", "उत्तर 2" or circle the number in the margin.
      - If the top of the page has no question marker, it usually continues the last question from the previous page.
      - legibility is your confidence (0 to 1) that the transcript is accurate.
    TXT

    def call
      previous_q = nil
      @collected = Hash.new { |h, k| h[k] = { parts: [], legibility: [], language: [], region_ids: [] } }

      book.pages.includes(:regions).each do |page|
        previous_q = read_page(page, previous_q)
      end

      save_answers
    end

    private

    def schema
      {
        type: "object",
        additionalProperties: false,
        required: %w[answers page_notes],
        properties: {
          answers: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              required: %w[question_number region_ids transcript language legibility continues_previous],
              properties: {
                question_number: { type: "string", enum: question_numbers + ["unknown"] },
                region_ids: { type: "array", items: { type: "string" } },
                transcript: { type: "string" },
                language: { type: "string", enum: %w[hindi english mixed other] },
                legibility: { type: "number" },
                continues_previous: { type: "boolean" }
              }
            }
          },
          page_notes: { type: "string" }
        }
      }
    end

    def read_page(page, previous_q)
      regions_text =
        if page.regions.any?
          dims = page.width && page.height ? " on a #{page.width}×#{page.height} px image" : ""
          lines = page.regions.map { |r| "R#{r.label_index}: x1=#{r.x1}, y1=#{r.y1}, x2=#{r.x2}, y2=#{r.y2}" }
          "Handwriting blocks detected by a segmentation model#{dims} (use these ids in region_ids):\n#{lines.join("\n")}"
        else
          "No handwriting blocks were detected automatically; read the whole page and leave region_ids empty."
        end

      question_list = questions.map { |q| "- #{q.number}: #{q.prompt.to_s.squish.truncate(160)}" }.join("\n")
      prompt = <<~TXT
        Page #{page.number} of answer book "#{book.student_label}".
        Allowed question numbers and what they ask:
        #{question_list}

        Last question seen on the previous page: #{previous_q || 'none (this is the first page)'}.

        #{regions_text}

        Return every answer (or continuation of an answer) visible on this page, top to bottom.
      TXT

      last_q = previous_q
      trace("read", model: self.class.reader_model, summary: "Page #{page.number}") do
        r = client.respond(
          model: self.class.reader_model,
          instructions: INSTRUCTIONS,
          input: MetaApi::Client.user_message(MetaApi::Client.text_part(prompt),
                                              MetaApi::Client.image_part(page_data_url(page))),
          schema: schema, schema_name: "page_transcription", reasoning: "medium"
        )
        answers = Array(r.json["answers"])
        answers.each do |a|
          qn = a["question_number"].to_s
          qn = previous_q if qn == "unknown" && a["continues_previous"] && previous_q
          next if qn.blank? || qn == "unknown"

          entry = @collected[qn]
          entry[:parts] << "[Page #{page.number}] #{a['transcript'].to_s.strip}"
          entry[:legibility] << a["legibility"].to_f
          entry[:language] << a["language"]
          ids = Array(a["region_ids"]).map { |id| id.to_s.delete("^0-9").to_i }.reject(&:zero?)
          entry[:region_ids].concat(ids.map { |i| [page.id, i] })
          page.regions.where(label_index: ids).update_all(question_number: qn)
          last_q = qn
        end
        summary = "Page #{page.number}: found #{answers.size} answer part(s)" \
                  "#{answers.any? ? " (#{answers.map { |a| a['question_number'] }.uniq.join(', ')})" : ''}"
        [r, summary]
      end
      last_q
    end

    def save_answers
      questions.each do |q|
        entry = @collected[q.number] if @collected.key?(q.number)
        answer = book.answers.find_or_initialize_by(question: q)
        if entry
          langs = entry[:language].compact.uniq
          answer.assign_attributes(
            transcript: entry[:parts].join("\n\n"),
            reading_confidence: entry[:legibility].min,
            detected_language: langs.size > 1 ? "mixed" : langs.first,
            region_ids_json: entry[:region_ids].to_json
          )
        else
          answer.assign_attributes(transcript: "", reading_confidence: 1.0, detected_language: nil, region_ids_json: "[]")
        end
        answer.save!
      end
    end
  end
end
