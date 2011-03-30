require "test/unit"
require "ribusb/compat"

class TestRibusbCompat < Test::Unit::TestCase
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
        assert_match(/ConfigDescriptor/, config_desc.inspect, "ConfigDescriptor#inspect should work")
        assert dev.configurations.include?(config_desc), "Device#configurations should include this one"

        config_desc.interfaces.each do |interface|
          assert_match(/Interface/, interface.inspect, "Interface#inspect should work")

          assert dev.interfaces.include?(interface), "Device#interfaces should include this one"
          assert config_desc.interfaces.include?(interface), "ConfigDescriptor#interfaces should include this one"

          interface.settings.each do |if_desc|
            assert_match(/InterfaceDescriptor/, if_desc.inspect, "InterfaceDescriptor#inspect should work")

            assert dev.settings.include?(if_desc), "Device#settings should include this one"
            assert config_desc.settings.include?(if_desc), "ConfigDescriptor#settings should include this one"
            assert interface.settings.include?(if_desc), "Inteerface#settings should include this one"

            if_desc.endpoints.each do |ep|
              assert_match(/EndpointDescriptor/, ep.inspect, "EndpointDescriptor#inspect should work")

              assert dev.endpoints.include?(ep), "Device#endpoints should include this one"
              assert config_desc.endpoints.include?(ep), "ConfigDescriptor#endpoints should include this one"
              assert interface.endpoints.include?(ep), "Inteerface#endpoints should include this one"
              assert if_desc.endpoints.include?(ep), "InterfaceDescriptor#endpoints should include this one"

              assert_equal if_desc, ep.setting, "backref should be correct"
              assert_equal interface, ep.interface, "backref should be correct"
              assert_equal config_desc, ep.configuration, "backref should be correct"
              assert_equal dev, ep.device, "backref should be correct"

              assert_operator 0, :<, ep.wMaxPacketSize, "packet size should be > 0"
            end
          end
        end
      end
    end
  end
  
  def test_open_mass_storage
    devs = []
    USB.each_device_by_class(USB_CLASS_MASS_STORAGE, 0x01, 0x50){|dev| devs << dev }
    USB.each_device_by_class(USB_CLASS_MASS_STORAGE, 0x06, 0x50){|dev| devs << dev }

    dev = devs.last
    abort "no mass storage device found" unless dev
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
        assert_match(/entity not found/, e.to_s, "Raise proper exception, if no kernel driver is active")
      end
    end

    endpoint_in = dev.endpoints.find{|ep| ep.bEndpointAddress&USB_ENDPOINT_IN != 0 }.bEndpointAddress
    endpoint_out = dev.endpoints.find{|ep| ep.bEndpointAddress&USB_ENDPOINT_IN == 0 }.bEndpointAddress

    devh.set_configuration 1
    devh.claim_interface 0
    devh.clear_halt(endpoint_in)
    devh.clear_halt(endpoint_out)
    devh.release_interface 0
    devh.usb_close
  end
end
