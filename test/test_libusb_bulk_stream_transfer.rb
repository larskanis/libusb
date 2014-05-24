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

require "minitest/autorun"
require "libusb"

class TestLibusbBulkStreamTransfer < Minitest::Test
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

  def test_alloc_streams
    assert_raises(ERROR_NOT_SUPPORTED, "TODO: test with a OS that supports bulk streams and against a real device") do
      nr_allocated = @dev.alloc_streams( 2, @dev.device.endpoints )
    end

    assert_raises(ERROR_NOT_SUPPORTED) do
      @dev.free_streams( [0x01,0x82] )
    end
  end

  def test_bulk_stream_transfer
    tr = BulkStreamTransfer.new :dev_handle=>@dev, :stream_id=>123, :buffer=>' '*100
    assert_equal 123, tr.stream_id, "stream_id should match"
  end
end
