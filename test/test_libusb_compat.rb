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
require "libusb/compat"

class TestLibusbCompat < Minitest::Test
  include USB

  attr_accessor :usb

  def test_find
    devlist = USB.devices
    assert_kind_of Array, devlist, "Bus#find should return an Array"
    assert_kind_of Device, devlist.first, "Bus#find should return Devices"
    devlist.each do |dev|
      assert_match( /Device/, dev.inspect, "Device#inspect should work")
    end
  end

  def test_constants
    assert_equal 7, USB_CLASS_PRINTER, "Printer class id should be defined"
    assert_equal 32, USB_TYPE_CLASS, "type class should be defined"
  end

  def test_descriptors
    USB.devices.each do |dev|
      assert_match(/Device/, dev.inspect, "Device#inspect should work")
      dev.configurations.each do |config_desc|
        assert_match(/Configuration/, config_desc.inspect, "Configuration#inspect should work")
        assert dev.configurations.include?(config_desc), "Device#configurations should include this one"

        config_desc.interfaces.each do |interface|
          assert_match(/Interface/, interface.inspect, "Interface#inspect should work")

          assert dev.interfaces.include?(interface), "Device#interfaces should include this one"
          assert config_desc.interfaces.include?(interface), "Configuration#interfaces should include this one"

          interface.settings.each do |if_desc|
            assert_match(/Setting/, if_desc.inspect, "Setting#inspect should work")

            assert dev.settings.include?(if_desc), "Device#settings should include this one"
            assert config_desc.settings.include?(if_desc), "Configuration#settings should include this one"
            assert interface.settings.include?(if_desc), "Interface#settings should include this one"

            if_desc.endpoints.each do |ep|
              assert_match(/Endpoint/, ep.inspect, "Endpoint#inspect should work")

              assert dev.endpoints.include?(ep), "Device#endpoints should include this one"
              assert config_desc.endpoints.include?(ep), "Configuration#endpoints should include this one"
              assert interface.endpoints.include?(ep), "Interface#endpoints should include this one"
              assert if_desc.endpoints.include?(ep), "Setting#endpoints should include this one"

              assert_equal if_desc, ep.setting, "backref should be correct"
              assert_equal interface, ep.interface, "backref should be correct"
              assert_equal config_desc, ep.configuration, "backref should be correct"
              assert_equal dev, ep.device, "backref should be correct"

              assert_operator 0, :<=, ep.wMaxPacketSize, "packet size should be > 0"
            end
          end
        end
      end
    end
  end
end
