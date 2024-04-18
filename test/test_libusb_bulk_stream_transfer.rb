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
    c.devices.each do |dev|
      if [:SPEED_SUPER, :SPEED_SUPER_PLUS].include?(dev.device_speed)
        dev.endpoints.each do |ep|
          if ep.transfer_type == :bulk
            ss = ep.ss_companion
            if ss.bmAttributes & 0x1f > 0
              @dev = dev.open
              break
            end
          end
        end
      end
    end
  end

  def teardown
    @dev.close if @dev
  end

  def test_alloc_streams
    skip "no device found with bulk stream support" unless @dev

    nr_allocated = @dev.alloc_streams( 2, @dev.device.endpoints )
    assert_equal 2, nr_allocated

    # TODO: test with a OS that supports bulk streams and against a real device

    @dev.free_streams( [0x01,0x82] )
  end

  def test_bulk_stream_transfer
    c = Context.new
    dev = c.devices.first.open
    tr = BulkStreamTransfer.new dev_handle: dev, stream_id: 123, buffer: ' '*100
    assert_equal 123, tr.stream_id, "stream_id should match"
    dev.close
  end
end
