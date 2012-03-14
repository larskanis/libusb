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

require "test/unit"
require "libusb"

class TestLibusbMassStorage2 < Test::Unit::TestCase
  include LIBUSB

  attr_accessor :usb
  attr_accessor :device

  def setup
    @usb = Context.new
    @usb.debug = 3
    @device = usb.devices( :bClass=>CLASS_MASS_STORAGE, :bSubClass=>[0x06,0x01], :bProtocol=>0x50 ).last
    abort "no mass storage device found" unless @device

    # Ensure kernel driver is detached
    device.open do |dev|
      if RUBY_PLATFORM=~/linux/i && dev.kernel_driver_active?(0)
        dev.detach_kernel_driver(0)
      end
    end
  end

  def teardown
  end

  def test_open_with_block
    device.open do |dev|
      assert_kind_of DevHandle, dev
      assert_kind_of String, dev.string_descriptor_ascii(1)
    end
  end

  def test_claim_interface_with_block
    res = device.open do |dev|
      dev.claim_interface(0) do |dev2|
        assert_kind_of DevHandle, dev2
        assert_kind_of String, dev2.string_descriptor_ascii(1)
        12345
      end
    end
    assert_equal 12345, res, "Block versions should pass through the result"
  end

  def test_open_interface
    res = device.open_interface(0) do |dev|
      assert_kind_of DevHandle, dev
      assert_kind_of String, dev.string_descriptor_ascii(1)
      12345
    end
    assert_equal 12345, res, "Block versions should pass through the result"
  end
end
