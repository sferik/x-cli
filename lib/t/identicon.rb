module T
  class Identicon
    # Six-bit number (0-63)
    attr_accessor :bits

    # Eight-bit number (0-255)
    attr_accessor :color

    def initialize(number)
      # Bottom six bits
      @bits = number & 0x3f

      # Next highest eight bits
      @fcolor = (number >> 6) & 0xff

      # Next highest eight bits
      @bcolor = (number >> 14) & 0xff
    end

    def lines
      ["#{bg @bits[0]}  #{bg @bits[1]}  #{bg @bits[0]}  #{reset}",
       "#{bg @bits[2]}  #{bg @bits[3]}  #{bg @bits[2]}  #{reset}",
       "#{bg @bits[4]}  #{bg @bits[5]}  #{bg @bits[4]}  #{reset}"]
    end

  private

    def reset
      "\033[0m"
    end

    def bg(bit)
      bit.zero? ? "\033[48;5;#{@bcolor}m" : "\033[48;5;#{@fcolor}m"
    end
  end

  class << Identicon
    def for_user_name(string)
      Identicon.new(digest(string))
    end

  private

    def digest(string)
      require "digest"
      Digest::MD5.digest(string).chars.inject(0) { |acc, elem| (acc << 8) | elem.ord }
    end
  end
end
