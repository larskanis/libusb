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

class TestLibusbDescriptors < Test::Unit::TestCase
  include LIBUSB

  attr_accessor :usb

  def setup
    @usb = Context.new
    @usb.debug = 0
  end

  def test_descriptors
    usb.devices.each do |dev|
      assert_match(/Device/, dev.inspect, "Device#inspect should work")

      assert_kind_of Integer, dev.bLength
      assert_equal 1, dev.bDescriptorType
      assert_kind_of Integer, dev.bcdUSB
      assert_kind_of Integer, dev.bDeviceClass
      assert_kind_of Integer, dev.bDeviceSubClass
      assert_kind_of Integer, dev.bDeviceProtocol
      assert_kind_of Integer, dev.bMaxPacketSize0
      assert_kind_of Integer, dev.idVendor
      assert_kind_of Integer, dev.idProduct
      assert_kind_of Integer, dev.bcdDevice
      assert_kind_of Integer, dev.iManufacturer
      assert_kind_of Integer, dev.iProduct
      assert_kind_of Integer, dev.iSerialNumber
      assert_kind_of Integer, dev.bNumConfigurations

      dev.configurations.each do |config_desc|
        assert_match(/Configuration/, config_desc.inspect, "ConfigDescriptor#inspect should work")
        assert dev.configurations.include?(config_desc), "Device#configurations should include this one"

        assert_kind_of Integer, config_desc.bLength
        assert_equal 2, config_desc.bDescriptorType
        assert_kind_of Integer, config_desc.wTotalLength
        assert_equal config_desc.interfaces.length, config_desc.bNumInterfaces
        assert_kind_of Integer, config_desc.bConfigurationValue
        assert_kind_of Integer, config_desc.iConfiguration
        assert_kind_of Integer, config_desc.bmAttributes
        assert_kind_of Integer, config_desc.maxPower
        assert_kind_of String, config_desc.extra if config_desc.extra

        config_desc.interfaces.each do |interface|
          assert_match(/Interface/, interface.inspect, "Interface#inspect should work")

          assert dev.interfaces.include?(interface), "Device#interfaces should include this one"
          assert config_desc.interfaces.include?(interface), "ConfigDescriptor#interfaces should include this one"

          interface.alt_settings.each do |if_desc|
            assert_match(/Setting/, if_desc.inspect, "InterfaceDescriptor#inspect should work")

            assert dev.settings.include?(if_desc), "Device#settings should include this one"
            assert config_desc.settings.include?(if_desc), "ConfigDescriptor#settings should include this one"
            assert interface.alt_settings.include?(if_desc), "Inteerface#alt_settings should include this one"

            assert_kind_of Integer, if_desc.bLength
            assert_equal 4, if_desc.bDescriptorType
            assert_kind_of Integer, if_desc.bInterfaceNumber
            assert_kind_of Integer, if_desc.bAlternateSetting
            assert_equal if_desc.endpoints.length, if_desc.bNumEndpoints
            assert_kind_of Integer, if_desc.bInterfaceClass
            assert_kind_of Integer, if_desc.bInterfaceSubClass
            assert_kind_of Integer, if_desc.bInterfaceProtocol
            assert_kind_of Integer, if_desc.iInterface
            assert_kind_of String, if_desc.extra if if_desc.extra

            if_desc.endpoints.each do |ep|
              assert_match(/Endpoint/, ep.inspect, "EndpointDescriptor#inspect should work")

              assert dev.endpoints.include?(ep), "Device#endpoints should include this one"
              assert config_desc.endpoints.include?(ep), "ConfigDescriptor#endpoints should include this one"
              assert interface.endpoints.include?(ep), "Inteerface#endpoints should include this one"
              assert if_desc.endpoints.include?(ep), "InterfaceDescriptor#endpoints should include this one"

              assert_equal if_desc, ep.setting, "backref should be correct"
              assert_equal interface, ep.interface, "backref should be correct"
              assert_equal config_desc, ep.configuration, "backref should be correct"
              assert_equal dev, ep.device, "backref should be correct"

              assert_kind_of Integer, ep.bLength
              assert_equal 5, ep.bDescriptorType
              assert_kind_of Integer, ep.bEndpointAddress
              assert_kind_of Integer, ep.bmAttributes
              assert_operator 0, :<, ep.wMaxPacketSize, "packet size should be > 0"
              assert_kind_of Integer, ep.bInterval
              assert_kind_of Integer, ep.bRefresh
              assert_kind_of Integer, ep.bSynchAddress
              assert_kind_of String, ep.extra if ep.extra
            end
          end
        end
      end
    end
  end

  def test_constants
    assert_equal 7, CLASS_PRINTER, "Printer class id should be defined"
    assert_equal 48, ISO_USAGE_TYPE_MASK, "iso usage type should be defined"
  end

  def test_device_filter_mass_storages
    devs1 = []
    usb.devices.each do |dev|
      dev.settings.each do |if_desc|
        if if_desc.bInterfaceClass == CLASS_MASS_STORAGE &&
              ( if_desc.bInterfaceSubClass == 0x01 ||
                if_desc.bInterfaceSubClass == 0x06 ) &&
              if_desc.bInterfaceProtocol == 0x50

          devs1 << dev
        end
      end
    end

    devs2 =  usb.devices( :bClass=>CLASS_MASS_STORAGE, :bSubClass=>0x01, :bProtocol=>0x50 )
    devs2 += usb.devices( :bClass=>CLASS_MASS_STORAGE, :bSubClass=>0x06, :bProtocol=>0x50 )
    assert_equal devs1.sort, devs2.sort, "devices and devices with filter should deliver the same device"

    devs3 =  usb.devices( :bClass=>[CLASS_MASS_STORAGE], :bSubClass=>[0x01,0x06], :bProtocol=>[0x50] )
    assert_equal devs1.sort, devs3.sort, "devices and devices with array-filter should deliver the same device"
  end

  def test_device_filter_hubs
    devs1 = []
    usb.devices.each do |dev|
      dev.settings.each do |if_desc|
        if if_desc.bInterfaceClass == CLASS_HUB
          devs1 << dev
        end
      end
    end

    devs2 = usb.devices( :bClass=>CLASS_HUB )
    assert_equal devs1.sort, devs2.sort, "devices and devices with filter should deliver the same device"
  end

  def test_device_methods
    usb.devices.each do |dev|
      ep = dev.endpoints.first
      if ep
        assert_operator dev.max_packet_size(ep), :>, 0, "#{dev.inspect} should have a usable packet size"
        assert_operator dev.max_packet_size(ep.bEndpointAddress), :>, 0, "#{dev.inspect} should have a usable packet size"
        assert_operator dev.max_iso_packet_size(ep), :>, 0, "#{dev.inspect} should have a usable iso packet size"
        assert_operator dev.max_iso_packet_size(ep.bEndpointAddress), :>, 0, "#{dev.inspect} should have a usable iso packet size"
        assert_operator dev.bus_number, :>=, 0, "#{dev.inspect} should have a bus_number"
        assert_operator dev.device_address, :>=, 0, "#{dev.inspect} should have a device_address"
        assert_operator([:SPEED_UNKNOWN, :SPEED_LOW, :SPEED_FULL, :SPEED_HIGH, :SPEED_SUPER], :include?, dev.device_speed, "#{dev.inspect} should have a device_speed")
        path = dev.port_path
        assert_kind_of Array, path, "#{dev.inspect} should have a port_path"
        path.each do |port|
          assert_operator port, :>, 0, "#{dev.inspect} should have proper port_path entries"
        end
        assert_equal path[-1], dev.port_number, "#{dev.inspect} should have a port number out of the port_path"
        if parent=dev.parent
          assert_kind_of Device, parent, "#{dev.inspect} should have a parent"
          assert_equal path[-2], parent.port_number, "#{dev.inspect} should have a parent port number out of the port_path"
        end
      end
    end
  end
end
