class Region < ApplicationRecord
  belongs_to :page

  # Box position as percentages of the page, for the review-screen overlay.
  def css_box(page_width, page_height)
    return nil unless page_width.to_i.positive? && page_height.to_i.positive?

    left = 100.0 * x1 / page_width
    top = 100.0 * y1 / page_height
    width = 100.0 * (x2 - x1) / page_width
    height = 100.0 * (y2 - y1) / page_height
    format("left:%.2f%%;top:%.2f%%;width:%.2f%%;height:%.2f%%", left, top, width, height)
  end
end
