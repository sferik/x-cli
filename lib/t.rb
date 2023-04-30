require "t/cli"
require "time"

module T
  class << self
    # Convert time to local time by applying the `utc_offset` setting.
    def local_time(time)
      time = time.dup
      utc_offset ? (time.utc + utc_offset) : time.localtime
    end

    # UTC offset in seconds to apply time instances before displaying.
    # If not set, time instances are displayed in default local time.
    attr_reader :utc_offset

    def utc_offset=(offset)
      @utc_offset = case offset
      when String
        Time.zone_offset(offset)
      when NilClass
        nil
      else
        offset.to_i
      end
    end
  end
end
