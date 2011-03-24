# These tests should be started with valgrind to check for
# invalid memmory access.

require "test/unit"
require "ribusb"

class TestRibusbGc < Test::Unit::TestCase
  include RibUSB

  def get_some_endpoint
    Context.new.find do |dev|
      return dev.endpoints.last
    end
  end

  def test_descriptors
    ep = get_some_endpoint
    ps = ep.wMaxPacketSize
    GC.start
    assert_equal ps, ep.wMaxPacketSize, "GC should not free EndpointDescriptor"
  end
end
