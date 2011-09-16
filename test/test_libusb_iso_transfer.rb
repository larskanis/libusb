require "test/unit"
require "libusb"

class TestLibusbIsoTransfer < Test::Unit::TestCase
  include LIBUSB

  def setup
    c = Context.new
    @dev = c.devices.first.open
  end

  def teardown
    @dev.close if @dev
  end

  def test_iso_transfer
    tr = IsochronousTransfer.new 10, :dev_handle=>@dev
    assert_equal 10, tr.num_packets, "number of packets should match"

    tr.buffer = " "*130
    tr.packet_lengths = 13
    tr[7].length = 12
    assert_equal 12, tr[7].length, "packet length should be set"
    assert_equal 13, tr[8].length, "packet length should be set"

    assert_raise(LIBUSB::ERROR_IO, "the randomly choosen device will probably not handle iso transfer") do
      tr.submit!
    end
  end
end
