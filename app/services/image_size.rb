# frozen_string_literal: true

# Reads width/height from PNG or JPEG bytes without any image library.
module ImageSize
  module_function

  def of(bytes)
    bytes = bytes.b
    if bytes.start_with?("\x89PNG\r\n\x1A\n".b) && bytes.bytesize >= 24
      return bytes[16, 8].unpack("NN")
    end
    return jpeg(bytes) if bytes.start_with?("\xFF\xD8".b)

    nil
  end

  SOF_MARKERS = ((0xC0..0xCF).to_a - [0xC4, 0xC8, 0xCC]).freeze

  def jpeg(bytes)
    i = 2
    while i + 9 < bytes.bytesize
      unless bytes.getbyte(i) == 0xFF
        i += 1
        next
      end
      marker = bytes.getbyte(i + 1)
      if marker == 0xFF # fill byte
        i += 1
        next
      end
      if marker == 0xD8 || marker == 0x01 || (0xD0..0xD7).cover?(marker)
        i += 2
        next
      end
      length = bytes[i + 2, 2].unpack1("n")
      if SOF_MARKERS.include?(marker)
        height, width = bytes[i + 5, 4].unpack("nn")
        return [width, height]
      end
      i += 2 + length
    end
    nil
  end
end
