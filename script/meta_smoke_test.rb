# Quick check that your Meta Model API key works — no Rails needed.
#
#   MODEL_API_KEY=xxx ruby script/meta_smoke_test.rb                 # text test
#   MODEL_API_KEY=xxx ruby script/meta_smoke_test.rb page.jpg        # + vision + SAM test
#   SAM_PROMPT="handwritten paragraph" MODEL_API_KEY=xxx ruby script/meta_smoke_test.rb page.jpg
$LOAD_PATH.unshift File.expand_path("../app/services", __dir__)
require "meta_api/error"
require "meta_api/retryable_error"
require "meta_api/client"
require "meta_api/sam_parser"

client = MetaApi::Client.new

puts "1) Text: muse-spark-1.3"
r = client.respond(model: "muse-spark-1.3", input: "Say 'ExamEval is ready' in Hindi, one line.")
puts "   → #{r.text.strip}  (#{r.usage.inspect})"

image = ARGV[0]
exit unless image

bytes = File.binread(image)
type = image.downcase.end_with?(".png") ? "image/png" : "image/jpeg"
url = MetaApi::Client.image_data_url(bytes, type)

puts "2) Vision: transcribe the first lines"
r = client.respond(model: "muse-spark-1.3",
                   input: MetaApi::Client.user_message(
                     MetaApi::Client.text_part("Transcribe the first 3 handwritten lines exactly as written (keep Hindi in Devanagari)."),
                     MetaApi::Client.image_part(url)))
puts r.text.strip.lines.map { |l| "   #{l}" }.join

prompt = ENV.fetch("SAM_PROMPT", "handwritten text")
puts "3) SAM 3.1 with prompt “#{prompt}”"
r = client.stream_text(model: "sam-3.1",
                       input: MetaApi::Client.user_message(MetaApi::Client.text_part(prompt),
                                                           MetaApi::Client.image_part(url)),
                       metadata: { "include_confidence" => "true", "mask_encoding" => "one_bit" })
boxes = MetaApi::SamParser.parse(r.text)
blocks = MetaApi::SamParser.merge_into_blocks(boxes)
puts "   #{boxes.size} box(es) → #{blocks.size} merged answer block(s)"
blocks.each_with_index { |b, i| puts "   R#{i + 1}: (#{b.x1},#{b.y1})–(#{b.x2},#{b.y2}) c=#{b.confidence}" }
