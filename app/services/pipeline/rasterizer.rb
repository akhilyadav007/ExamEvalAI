# frozen_string_literal: true

require "open3"
require "tmpdir"

module Pipeline
  # Step 1: turn uploaded PDFs / phone photos into normalised page images (JPEG, ≤2000px).
  # Uses `pdftoppm` (poppler-utils) for PDFs and ImageMagick (if present) to fix
  # phone-photo rotation and size. No API calls.
  class Rasterizer < Base
    MAX_EDGE = 2000

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      number = 0
      Dir.mktmpdir("exameval") do |dir|
        book.uploads.each_with_index do |upload, idx|
          upload.blob.open do |file|
            page_files_for(file.path, upload.blob.content_type, dir, idx).each do |path|
              number += 1
              create_page(number, path)
            end
          end
        end
      end
      raise MetaApi::Error, "No pages found in the upload" if number.zero?

      book.agent_steps.create!(step: "rasterize", model: "pdftoppm/imagemagick", status: "ok",
                               summary: "Prepared #{number} page image(s)", duration_ms: elapsed_ms(started))
    end

    private

    def page_files_for(path, content_type, dir, idx)
      if content_type == "application/pdf"
        prefix = File.join(dir, "u#{idx}")
        run!("pdftoppm", "-jpeg", "-jpegopt", "quality=85", "-scale-to", MAX_EDGE.to_s, path, prefix)
        Dir.glob("#{prefix}-*.jpg").sort_by { |p| p[/-(\d+)\.jpg\z/, 1].to_i }
      elsif (im = imagemagick)
        out = File.join(dir, "u#{idx}.jpg")
        run!(*im, path, "-auto-orient", "-resize", "#{MAX_EDGE}x#{MAX_EDGE}>", "-quality", "85", out)
        [out]
      else
        [path]
      end
    end

    def create_page(number, path)
      bytes = File.binread(path)
      width, height = ImageSize.of(bytes)
      content_type = bytes.start_with?("\x89PNG".b) ? "image/png" : "image/jpeg"
      page = book.pages.create!(number: number, width: width, height: height)
      page.image.attach(io: StringIO.new(bytes), filename: "page-#{number}.#{content_type.split('/').last}",
                        content_type: content_type)
    end

    def imagemagick
      @imagemagick ||= if system("which magick > /dev/null 2>&1") then ["magick"]
                       elsif system("which convert > /dev/null 2>&1") then ["convert"]
                       end
    end

    def run!(*cmd)
      _out, err, status = Open3.capture3(*cmd)
      raise MetaApi::Error, "#{cmd.first} failed: #{err.strip}" unless status.success?
    end
  end
end
