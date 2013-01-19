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
require "libusb/compat"

class TestLibusbCompatMassStorage < Test::Unit::TestCase
  include USB

  attr_accessor :devh

  BOMS_RESET = 0xFF
  BOMS_GET_MAX_LUN = 0xFE

  def setup
    devs = []
    USB.each_device_by_class(USB_CLASS_MASS_STORAGE, 0x01, 0x50){|dev| devs << dev }
    USB.each_device_by_class(USB_CLASS_MASS_STORAGE, 0x06, 0x50){|dev| devs << dev }

    dev = devs.last
    skip "no mass storage device found" unless dev
    devh = dev.open
    if RUBY_PLATFORM=~/linux/i
      data = " "*1000
      begin
        devh.usb_get_driver_np 0, data
      rescue Errno::ENODATA
        data = "nodata exception".ljust(1000, "\0")
      end
      assert_match(/\w+/, data, "There should be a driver or an exception")
      begin
        # second param is needed because of a bug in ruby-usb
        devh.usb_detach_kernel_driver_np 0, 123
      rescue RuntimeError => e
        assert_match(/ERROR_NOT_FOUND/, e.to_s, "Raise proper exception, if no kernel driver is active")
      end
    end

    endpoint_in = dev.endpoints.find{|ep| ep.bEndpointAddress&USB_ENDPOINT_IN != 0 }
    endpoint_out = dev.endpoints.find{|ep| ep.bEndpointAddress&USB_ENDPOINT_IN == 0 }

    devh.set_configuration 1
    devh.set_configuration dev.configurations.first
    devh.claim_interface dev.settings.first
    devh.clear_halt(endpoint_in)
    devh.clear_halt(endpoint_out.bEndpointAddress)
    @devh = devh
  end

  def teardown
    if devh
      devh.release_interface 0
      devh.usb_close
    end
  end

  def test_mass_storage_reset
    res = devh.usb_control_msg(USB_ENDPOINT_OUT|USB_TYPE_CLASS|USB_RECIP_INTERFACE,
                BOMS_RESET, 0, 0, "", 2000)
    assert_equal 0, res, "BOMS_RESET response should be 0 byte"
  end

  def test_read_max_lun
    bytes = [].pack('x1')
    devh.usb_control_msg(USB_ENDPOINT_IN|USB_TYPE_CLASS|USB_RECIP_INTERFACE,
                BOMS_GET_MAX_LUN, 0, 0, bytes, 100)
    assert [0].pack("C")==bytes || [1].pack("C")==bytes, "BOMS_GET_MAX_LUN response is usually 0 or 1"
  end
end
