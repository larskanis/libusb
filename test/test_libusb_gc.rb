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

require "test/unit"
require "libusb"

class TestLibusbGc < Test::Unit::TestCase
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
end
