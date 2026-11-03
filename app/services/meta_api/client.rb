# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "uri"

# Minimal client for Meta Model API (https://dev.meta.ai/docs).
# Plain Ruby on purpose (no gems, no ActiveSupport) so it also runs in
# script/meta_smoke_test.rb outside Rails.
module MetaApi
  class Client
    Result = Struct.new(:text, :json, :usage, :raw, keyword_init: true)

    RETRY_CODES = [408, 409, 429, 500, 502, 503, 504].freeze

    def self.base_url
      ENV.fetch("META_API_BASE_URL", "https://api.meta.ai/v1")
    end

    def initialize(api_key: ENV["MODEL_API_KEY"], timeout: 240)
      raise Error, "MODEL_API_KEY is not set" if api_key.to_s.strip.empty?

      @api_key = api_key
      @timeout = timeout
    end

    # Non-streaming Responses API call.
    # Pass `schema:` (a JSON Schema hash) to get structured JSON back in result.json.
    def respond(model:, input:, instructions: nil, schema: nil, schema_name: "result",
                reasoning: nil, max_output_tokens: nil, metadata: nil)
      body = { model: model, input: input }
      body[:instructions] = instructions if instructions
      body[:reasoning] = { effort: reasoning } if reasoning
      body[:max_output_tokens] = max_output_tokens if max_output_tokens
      body[:metadata] = metadata if metadata
      if schema
        body[:text] = { format: { type: "json_schema", name: schema_name, schema: schema, strict: false } }
      end

      data = post_json("/responses", body)
      text = self.class.extract_output_text(data)
      json = schema ? self.class.parse_json(text) : nil
      Result.new(text: text, json: json, usage: data["usage"], raw: data)
    end

    # Streaming Responses API call (SAM 3.1 returns its boxes/masks as streamed text).
    # Returns a Result whose text is all output_text deltas joined together.
    def stream_text(model:, input:, metadata: nil)
      body = { model: model, input: input, stream: true }
      body[:metadata] = metadata if metadata

      text = +""
      usage = nil
      buffer = +""
      post_stream("/responses", body) do |chunk|
        buffer << chunk.gsub("\r\n", "\n")
        while (idx = buffer.index("\n\n"))
          event = buffer.slice!(0, idx + 2)
          payload = event.lines
                         .select { |l| l.start_with?("data:") }
                         .map { |l| l.sub(/\Adata:\s?/, "").chomp }
                         .join("\n")
          next if payload.empty? || payload == "[DONE]"

          evt = begin
            JSON.parse(payload)
          rescue JSON::ParserError
            next
          end

          case evt["type"]
          when "response.output_text.delta"
            text << evt["delta"].to_s
          when "response.completed"
            usage = evt.dig("response", "usage")
          when "response.failed", "error"
            message = evt.dig("response", "error", "message") || evt.dig("error", "message") || evt.to_s
            raise Error, "Meta API stream error: #{message}"
          end
        end
      end
      Result.new(text: text, usage: usage, raw: nil)
    end

    # ---- helpers -----------------------------------------------------------

    def self.image_data_url(bytes, content_type)
      "data:#{content_type};base64,#{Base64.strict_encode64(bytes)}"
    end

    def self.user_message(*parts)
      [{ type: "message", role: "user", content: parts }]
    end

    def self.text_part(text)
      { type: "input_text", text: text }
    end

    def self.image_part(data_url)
      { type: "input_image", image_url: data_url }
    end

    def self.extract_output_text(data)
      top = data["output_text"]
      return top if top.is_a?(String) && !top.empty?

      Array(data["output"])
        .flat_map { |item| Array(item["content"]) }
        .select { |c| c["type"] == "output_text" }
        .map { |c| c["text"].to_s }
        .join
    end

    def self.parse_json(text)
      cleaned = text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/```\s*\z/, "").strip
      JSON.parse(cleaned)
    rescue JSON::ParserError
      first = cleaned.index("{")
      last = cleaned.rindex("}")
      raise Error, "Model did not return JSON: #{text.to_s[0, 300]}" unless first && last && last > first

      JSON.parse(cleaned[first..last])
    end

    private

    def endpoint(path)
      URI("#{self.class.base_url.chomp('/')}/#{path.delete_prefix('/')}")
    end

    def build_request(uri, body, accept)
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"] = "application/json"
      req["Accept"] = accept
      req.body = JSON.generate(body)
      req
    end

    def post_json(path, body)
      with_retries do
        uri = endpoint(path)
        http_start(uri) do |http|
          res = http.request(build_request(uri, body, "application/json"))
          check!(res, res.body)
          JSON.parse(res.body)
        end
      end
    end

    def post_stream(path, body, &block)
      with_retries do
        uri = endpoint(path)
        http_start(uri) do |http|
          http.request(build_request(uri, body, "text/event-stream")) do |res|
            if res.is_a?(Net::HTTPSuccess)
              res.read_body(&block)
            else
              check!(res, res.read_body)
            end
          end
        end
      end
    end

    def http_start(uri, &block)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: 20,
                      read_timeout: @timeout, &block)
    end

    def check!(res, body)
      return if res.is_a?(Net::HTTPSuccess)

      message = "Meta API #{res.code}: #{body.to_s[0, 600]}"
      raise RetryableError, message if RETRY_CODES.include?(res.code.to_i)

      raise Error, message
    end

    def with_retries(max_attempts: 4)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue RetryableError, Net::OpenTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED => e
        raise Error, e.message if attempts >= max_attempts

        sleep(2**attempts)
        retry
      end
    end
  end
end
