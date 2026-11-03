# frozen_string_literal: true

module Pipeline
  # Step 2 (SAM 3.1): find the handwritten answer blocks on each page.
  # SAM returns one box per match; we merge nearby boxes into answer blocks
  # and store them as Regions (R1, R2, ...) that the reader refers to.
  class Segmenter < Base
    def call
      book.pages.each { |page| segment(page) }
    end

    def self.prompt
      ENV.fetch("SAM_PROMPT", "handwritten text")
    end

    private

    def segment(page)
      result = trace("segment", model: self.class.sam_model, summary: "Page #{page.number}: “#{self.class.prompt}”") do
        r = client.stream_text(
          model: self.class.sam_model,
          input: MetaApi::Client.user_message(
            MetaApi::Client.text_part(self.class.prompt),
            MetaApi::Client.image_part(page_data_url(page))
          ),
          metadata: { "include_confidence" => "true", "mask_encoding" => "one_bit" }
        )
        boxes = MetaApi::SamParser.parse(r.text)
        blocks = MetaApi::SamParser.merge_into_blocks(boxes).first(15)
        save_regions(page, boxes, blocks, r.text)
        [r, "Page #{page.number}: #{boxes.size} match(es) → #{blocks.size} answer block(s)"]
      end
      result
    rescue MetaApi::Error => e
      # Segmentation is helpful but not essential: the reader can still read the whole page.
      Rails.logger.warn("[ExamEval] SAM failed on page #{page.id}: #{e.message}")
    end

    def save_regions(page, boxes, blocks, raw)
      if boxes.first && (page.width.nil? || page.height.nil?)
        page.width = boxes.first.width
        page.height = boxes.first.height
      end
      page.sam_raw = raw.to_s[0, 20_000]
      page.save!
      blocks.each_with_index do |b, i|
        page.regions.create!(label_index: i + 1, x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2, confidence: b.confidence)
      end
    end
  end
end
