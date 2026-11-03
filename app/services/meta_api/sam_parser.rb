# frozen_string_literal: true

# Parses SAM 3.1 text output into boxes.
# Format (https://dev.meta.ai/docs/sam/reading-segmentation):
#   <0f>0<|box;x1=181;y1=365;x2=556;y2=486;w=1516;h=1600;c=0.96|><|mask;...|>,2<|box;...|><|mask;...|>
# We only need the boxes (pixel corners, inclusive) plus the source frame size.
module MetaApi
  class SamParser
    Box = Struct.new(:object_id, :x1, :y1, :x2, :y2, :width, :height, :confidence, keyword_init: true) do
      def area
        [x2 - x1 + 1, 0].max * [y2 - y1 + 1, 0].max
      end
    end

    BOX_RE = /(\d*)<\|box;([^|]*)\|>/

    def self.parse(text)
      text.to_s.scan(BOX_RE).map do |obj_id, fields|
        f = fields.split(";").each_with_object({}) do |pair, h|
          k, v = pair.split("=", 2)
          h[k] = v if k && v
        end
        Box.new(
          object_id: obj_id.to_s.empty? ? nil : obj_id.to_i,
          x1: f["x1"].to_i, y1: f["y1"].to_i, x2: f["x2"].to_i, y2: f["y2"].to_i,
          width: f["w"]&.to_i, height: f["h"]&.to_i,
          confidence: f["c"]&.to_f
        )
      end
    end

    # Merge line-level boxes into answer blocks: boxes that overlap or sit within
    # `gap_ratio` of the page height vertically are joined into one block.
    def self.merge_into_blocks(boxes, gap_ratio: 0.025, min_area_ratio: 0.002, min_confidence: 0.25)
      return [] if boxes.empty?

      w = boxes.first.width.to_i
      h = boxes.first.height.to_i
      page_area = [w * h, 1].max
      gap = (h * gap_ratio).round

      kept = boxes.select do |b|
        b.area >= page_area * min_area_ratio && (b.confidence.nil? || b.confidence >= min_confidence)
      end
      kept.sort_by!(&:y1)

      blocks = []
      kept.each do |b|
        last = blocks.last
        if last && b.y1 <= last.y2 + gap
          last.x1 = [last.x1, b.x1].min
          last.y1 = [last.y1, b.y1].min
          last.x2 = [last.x2, b.x2].max
          last.y2 = [last.y2, b.y2].max
          last.confidence = [last.confidence, b.confidence].compact.max
        else
          blocks << b.dup
        end
      end
      blocks
    end
  end
end
