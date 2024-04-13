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

class TestLibusbBos < Minitest::Test
  include LIBUSB

  attr_accessor :usb

  def setup
    @usb = Context.new
    @usb.debug = 0
  end

  def test_bos
    did_bos = false
    did_cap = false
    usb.devices.each do |dev|
      # devices with USB version >= 0x201 could support bos
      # devices with USB version >= 0x210 must support bos
      if dev.bcdUSB >= 0x210
        dev.open do |devh|
          bos = devh.bos
          did_bos = true

          assert_equal 5, bos.bLength
          assert_equal 0x0f, bos.bDescriptorType
          assert_operator 5, :<=, bos.wTotalLength
          assert_operator 0, :<=, bos.bNumDeviceCaps

          caps = bos.device_capabilities
          assert_equal bos.bNumDeviceCaps, caps.length
          cap_types = bos.device_capability_types
          assert_equal bos.bNumDeviceCaps, cap_types.length

          cap_types.each do |cap_type|
            assert_operator [
                :BT_WIRELESS_USB_DEVICE_CAPABILITY,
                :BT_USB_2_0_EXTENSION,
                :BT_SS_USB_DEVICE_CAPABILITY,
                :BT_CONTAINER_ID,
                :BT_WIRELESS_USB_DEVICE_CAPABILITY,
                :BT_USB_2_0_EXTENSION,
                :BT_SS_USB_DEVICE_CAPABILITY,
                :BT_CONTAINER_ID,
                :BT_PLATFORM_DESCRIPTOR,
                :BT_POWER_DELIVERY_CAPABILITY,
                :BT_BATTERY_INFO_CAPABILITY,
                :BT_PD_CONSUMER_PORT_CAPABILITY,
                :BT_PD_PROVIDER_PORT_CAPABILITY,
                :BT_SUPERSPEED_PLUS,
                :BT_PRECISION_TIME_MEASUREMENT,
                :BT_Wireless_USB_Ext,
                :BT_BILLBOARD,
                :BT_AUTHENTICATION,
                :BT_BILLBOARD_EX,
                :BT_CONFIGURATION_SUMMARY,
                :BT_FWStatus_Capability,
              ], :include?, cap_type
          end


          caps.each do |cap|
            did_cap = true

            assert_operator 4, :<=, cap.bLength
            assert_equal LIBUSB::DT_DEVICE_CAPABILITY, cap.bDescriptorType
            assert_kind_of String, cap.dev_capability_data, "should provide binary capability data"
            assert_kind_of String, cap.inspect, "should respond to inspect"
            assert_operator 1, :<=, cap.dev_capability_data.length, "dev_capability_data should be at least one byte"

            case cap
              when Bos::DeviceCapability
                assert_kind_of Integer, cap.bDevCapabilityType

              when Bos::Usb20Extension
                assert_equal 2, cap.bDevCapabilityType
                assert_operator 0, :<=, cap.bmAttributes
                assert_operator [true, false], :include?, cap.bm_lpm_support?

              when Bos::SsUsbDeviceCapability
                assert_equal 3, cap.bDevCapabilityType
                assert_operator 0, :<=, cap.bmAttributes
                assert_operator [true, false], :include?, cap.bm_ltm_support?
                assert_operator 0, :<=, cap.wSpeedSupported
                assert_kind_of Array, cap.supported_speeds
                assert_operator 0, :<=, cap.bFunctionalitySupport
                assert_operator 0, :<=, cap.bU1DevExitLat
                assert_operator 0, :<=, cap.bU2DevExitLat

              when Bos::ContainerId
                assert_equal 4, cap.bDevCapabilityType
                assert_operator 0, :<=, cap.bReserved
                assert_operator 16, :==, cap.container_id.bytesize, "container_id should be 16 bytes long"

              when Bos::PlatformDescriptor
                assert_operator 0, :<=, cap.bReserved
                assert_operator 16, :==, cap.platformCapabilityUUID.bytesize, "container_id should be 16 bytes long"
                assert_kind_of String, cap.capabilityData

              else
                refute true, "invalid device capability class"
            end
          end
        end
      end
    end
    skip "no device with BOS available" unless did_bos
    skip "no device with BOS capability available" unless did_cap
  end

  def test_no_bos
    did_failing_bos = false

    # devices with USB version < 0x201 shouldn't support bos
    if dev=usb.devices.find{|dev| dev.bcdUSB < 0x201 }
      dev.open do |devh|
        assert_raises LIBUSB::ERROR_PIPE do
          devh.bos
        end
        did_failing_bos = true
      end
    end
    skip "no device without BOS available" unless did_failing_bos
  end
end
