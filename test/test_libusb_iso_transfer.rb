# This file is part of Libusb for Ruby.
#
# Libusb for Ruby is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Libusb for Ruby is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Libusb for Ruby.  If not, see <http://www.gnu.org/licenses/>.

require "test/unit"
require "libusb"

class TestLibusbIsoTransfer < Test::Unit::TestCase
  include LIBUSB

  def setup
    c = Context.new
    begin
      @dev = c.devices.first.open
    rescue LIBUSB::ERROR_ACCESS
      @dev = nil
      skip "error opening device"
    end
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
