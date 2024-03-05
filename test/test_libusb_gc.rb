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
#
# These tests should be started with valgrind to check for
# invalid memmory access.

require "minitest/autorun"
require "libusb"

class TestLibusbGc < Minitest::Test
  include LIBUSB

  def get_some_endpoint
    Context.new.devices.each do |dev|
      return dev.endpoints.last unless dev.endpoints.empty?
    end
  end

  def test_descriptors
    ep = get_some_endpoint
    ps = ep.wMaxPacketSize
    GC.start
    assert_equal ps, ep.wMaxPacketSize, "GC should not free EndpointDescriptor"
  end

  def test_log_cb
    LIBUSB.set_options OPTION_LOG_CB: proc{}, OPTION_LOG_LEVEL: LIBUSB::LOG_LEVEL_DEBUG

    c = LIBUSB::Context.new OPTION_LOG_CB: proc{}, OPTION_NO_DEVICE_DISCOVERY: nil
    GC.start
    c.devices
    c.set_log_cb(LIBUSB::LOG_CB_CONTEXT){}
    c.devices
    GC.start
    c.devices

  ensure
    LIBUSB.set_options OPTION_LOG_CB: [nil], OPTION_LOG_LEVEL: LIBUSB::LOG_LEVEL_NONE
  end
end
