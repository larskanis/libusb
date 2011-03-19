require "test/unit"
require "ribusb"

class TestRibusb < Test::Unit::TestCase
  include RibUSB

  attr_accessor :usb

  def setup
    @usb = Bus.new
  end

  def test_find
    devlist = usb.find
    assert_kind_of Array, devlist, "Bus#find should return an Array"
    assert_kind_of Device, devlist.first, "Bus#find should return Devices"

    usb.find do |dev|
      assert_equal devlist.shift.deviceAddress, dev.deviceAddress, "Bus#find with block should give same devices"
    end
  end
end
