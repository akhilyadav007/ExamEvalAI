module ApplicationHelper
  # 4.0 → "4", 6.5 → "6.5", nil → "–"
  def marks(value)
    return "–" if value.nil?

    v = value.to_d.round(1)
    v.frac.zero? ? v.to_i.to_s : v.to_s("F")
  end

  def percent(value)
    value.nil? ? "–" : "#{(value * 100).round}%"
  end

  def status_badge(status)
    tag.span(status.humanize, class: "badge badge-#{status}")
  end

  def verdict_badge(verdict)
    return "" if verdict.blank?

    label = { "agree" => "Moderator agrees", "adjusted" => "Moderator adjusted", "flag" => "Moderator flagged" }
    tag.span(label.fetch(verdict, verdict.humanize), class: "badge verdict-#{verdict}")
  end

  # A stable colour per question number for region boxes and card markers.
  QUESTION_COLORS = %w[#2563eb #db2777 #059669 #d97706 #7c3aed #0891b2 #dc2626 #65a30d].freeze

  def question_color(exam, number)
    idx = exam.questions.map(&:number).index(number.to_s)
    idx ? QUESTION_COLORS[idx % QUESTION_COLORS.size] : "#6b7280"
  end
end
