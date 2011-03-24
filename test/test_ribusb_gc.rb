# These tests should be started with valgrind to check for
# invalid memmory access.

require "test/unit"
require "ribusb"

class TestRibusbGc < Test::Unit::TestCase
  include RibUSB

  def get_some_endpoint
    Bus.new.find do |dev|
      dev.bNumConfigurations.times do |config_index|
        config_desc = dev.configDescriptor(config_index)
        config_desc.interfaceList.each do |interface|
          interface.altSettingList.each do |if_desc|
            return if_desc.endpointList.last
          end
        end
      end
    end
  end

  def test_descriptors
    ep = get_some_endpoint
    ps = ep.wMaxPacketSize
    GC.start
    assert_equal ps, ep.wMaxPacketSize, "GC should not free EndpointDescriptor"
  end
end
