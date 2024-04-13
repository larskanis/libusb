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

require 'libusb/call'

module LIBUSB
  # A structure representing the Binary Device Object Store (BOS) descriptor.
  # This descriptor is documented in section 9.6.2 of the USB 3.0 specification.
  # All multiple-byte fields are represented in host-endian format.
  class Bos < FFI::ManagedStruct

    module GenericMethods
      # @return [Integer]  Size of this descriptor (in bytes)
      def bLength
        self[:bLength]
      end

      # @return [Integer]  Descriptor type. Will have value LIBUSB::DT_DEVICE_CAPABILITY
      # in this context.
      def bDescriptorType
        self[:bDescriptorType]
      end

      # @return [Integer] Device Capability type
      def bDevCapabilityType
        self[:bDevCapabilityType]
      end

      def inspect
        "\#<#{self.class} cap: #{bDevCapabilityType} data: #{dev_capability_data.unpack("H*")[0]}>"
      end

      # @return [String]  Device Capability data (bLength - 3 bytes)
      def dev_capability_data
        pointer.read_bytes(bLength - 3)
      end
    end

    # A generic representation of a BOS Device Capability descriptor.
    class DeviceCapability < FFI::Struct
      include GenericMethods

      layout :bLength, :uint8,
          :bDescriptorType, :uint8,
          :bDevCapabilityType, :uint8

      def initialize( bos, *args)
        # Avoid that the bos struct is GC'ed before this instance
        @bos = bos
        super(*args)
      end
    end

    # A structure representing the USB 2.0 Extension descriptor
    # This descriptor is documented in section 9.6.2.1 of the USB 3.0 specification.
    # All multiple-byte fields are represented in host-endian format.
    class Usb20Extension < FFI::ManagedStruct
      include GenericMethods

      layout :bLength, :uint8,
          :bDescriptorType, :uint8,
          :bDevCapabilityType, :uint8,
          :bmAttributes, :uint32

      # Bitmap encoding of supported device level features.
      # A value of one in a bit location indicates a feature is
      # supported; a value of zero indicates it is not supported.
      # @see Call::Usb20ExtensionAttributes
      def bmAttributes
        self[:bmAttributes]
      end

      # @return [Boolean] Supports Link Power Management (LPM)
      def bm_lpm_support?
        (bmAttributes & BM_LPM_SUPPORT) != 0
      end

      def inspect
        attrs = Call::Usb20ExtensionAttributes.to_h.map do |k, v|
          (bmAttributes & v) ? k.to_s : nil
        end
        "\#<#{self.class} #{attrs.compact.join(",")}>"
      end

      # @private
      def self.release(ptr)
        Call.libusb_free_usb_2_0_extension_descriptor(ptr)
      end
    end

    # A structure representing the SuperSpeed USB Device Capability descriptor
    # This descriptor is documented in section 9.6.2.2 of the USB 3.0 specification.
    # All multiple-byte fields are represented in host-endian format.
    class SsUsbDeviceCapability < FFI::ManagedStruct
      include GenericMethods

      layout :bLength, :uint8,
          :bDescriptorType, :uint8,
          :bDevCapabilityType, :uint8,
          :bmAttributes, :uint8,
          :wSpeedSupported, :uint16,
          :bFunctionalitySupport, :uint8,
          :bU1DevExitLat, :uint8,
          :bU2DevExitLat, :uint16

      # Bitmap encoding of supported device level features.
      # A value of one in a bit location indicates a feature is
      # supported; a value of zero indicates it is not supported.
      #
      # @return [Integer]
      # @see Call::SsUsbDeviceCapabilityAttributes
      def bmAttributes
        self[:bmAttributes]
      end

      # @return [Boolean] Supports Latency Tolerance Messages (LTM)
      def bm_ltm_support?
        (bmAttributes & BM_LTM_SUPPORT) != 0
      end

      def inspect
        attrs = Call::SsUsbDeviceCapabilityAttributes.to_h.map do |k,v|
          (bmAttributes & v) != 0 ? k.to_s : nil
        end
        "\#<#{self.class} #{attrs.compact.join(",")} #{supported_speeds.join(",")}>"
      end

      # Bitmap encoding of the speed supported by this device when
      # operating in SuperSpeed mode.
      #
      # @return [Integer]
      # @see Call::SupportedSpeeds
      def wSpeedSupported
        self[:wSpeedSupported]
      end

      # @return [Array<Symbol>]  speeds supported by this device when
      #     operating in SuperSpeed mode {Call::SupportedSpeeds}
      def supported_speeds
        speeds = Call::SupportedSpeeds.to_h.map do |k,v|
          (wSpeedSupported & v) != 0 ? k : nil
        end
        speeds.compact
      end

      # The lowest speed at which all the functionality supported
      # by the device is available to the user. For example if the
      # device supports all its functionality when connected at
      # full speed and above then it sets this value to 1.
      #
      # 0 - low speed
      # 1 - full speed
      # 2 - high speed
      # 3 - super speed
      # @return [Integer]
      def bFunctionalitySupport
        self[:bFunctionalitySupport]
      end

      # @return [Integer]  U1 Device Exit Latency.
      def bU1DevExitLat
        self[:bU1DevExitLat]
      end

      # @return [Integer]  U2 Device Exit Latency.
      def bU2DevExitLat
        self[:bU2DevExitLat]
      end

      # @private
      def self.release(ptr)
        Call.libusb_free_ss_usb_device_capability_descriptor(ptr)
      end
    end

    # A structure representing the Container ID descriptor.
    # This descriptor is documented in section 9.6.2.3 of the USB 3.0 specification.
    # All multiple-byte fields, except UUIDs, are represented in host-endian format.
    class ContainerId < FFI::ManagedStruct
      include GenericMethods

      layout :bLength, :uint8,
          :bDescriptorType, :uint8,
          :bDevCapabilityType, :uint8,
          :bReserved, :uint8,
          :ContainerID, [:uint8, 16]

      # Reserved field
      def bReserved
        self[:bReserved]
      end

      # @return [String] 128 bit UUID
      def container_id
        self[:ContainerID].to_ptr.read_bytes(16)
      end

      def inspect
        "\#<#{self.class} #{container_id.unpack("H*")[0]}>"
      end

      # @private
      def self.release(ptr)
        Call.libusb_free_container_id_descriptor(ptr)
      end
    end

    def initialize( ctx, *args)
      @ctx = ctx
      super(*args)
    end

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :wTotalLength, :uint16,
        :bNumDeviceCaps, :uint8,
        :dev_capability, [:pointer, 0]

    # @return [Integer]  Size of this descriptor (in bytes)
    def bLength
      self[:bLength]
    end

    # @return [Integer]  Descriptor type. Will have value LIBUSB::DT_BOS LIBUSB_DT_BOS
    # in this context.
    def bDescriptorType
      self[:bDescriptorType]
    end

    # @return [Integer]  Length of this descriptor and all of its sub descriptors
    def wTotalLength
      self[:wTotalLength]
    end

    # @return [Integer]  The number of separate device capability descriptors in
    # the BOS
    def bNumDeviceCaps
      self[:bNumDeviceCaps]
    end

    # bNumDeviceCap Device Capability Descriptors
    #
    # @return [Array<Bos::DeviceCapability, Bos::Usb20Extension, Bos::SsUsbDeviceCapability, Bos::ContainerId>]
    def device_capabilities
      pp_ext = FFI::MemoryPointer.new :pointer
      caps = []
      # Capabilities are appended to the bos header
      ptr = pointer + offset_of(:dev_capability)
      bNumDeviceCaps.times do
        cap = DeviceCapability.new self, ptr.read_pointer
        case cap.bDevCapabilityType
          when LIBUSB::BT_WIRELESS_USB_DEVICE_CAPABILITY
            # no struct defined in libusb -> use generic DeviceCapability
          when LIBUSB::BT_USB_2_0_EXTENSION
            res = Call.libusb_get_usb_2_0_extension_descriptor(@ctx, cap.pointer, pp_ext)
            cap = Usb20Extension.new(pp_ext.read_pointer) if res==0
          when LIBUSB::BT_SS_USB_DEVICE_CAPABILITY
            res = Call.libusb_get_ss_usb_device_capability_descriptor(@ctx, cap.pointer, pp_ext)
            cap = SsUsbDeviceCapability.new(pp_ext.read_pointer) if res==0
          when LIBUSB::BT_CONTAINER_ID
            res = Call.libusb_get_container_id_descriptor(@ctx, cap.pointer, pp_ext)
            cap = ContainerId.new(pp_ext.read_pointer) if res==0
          else
            # unknown capability -> use generic DeviceCapability
        end
        ptr += FFI.type_size(:pointer)
        caps << cap
      end
      caps
    end

    # @return [Array<Symbol>]  Types of Capabilities
    #
    # @see Call::BosTypes
    def device_capability_types
      # Capabilities are appended to the bos header
      ptr = pointer + offset_of(:dev_capability)
      bNumDeviceCaps.times.map do
        cap = DeviceCapability.new self, ptr.read_pointer
        ptr += FFI.type_size(:pointer)
        Call::BosTypes.find cap.bDevCapabilityType
      end
    end

    def inspect
      "\#<#{self.class} #{device_capability_types.join(", ")}>"
    end

    # @private
    def self.release(ptr)
      Call.libusb_free_bos_descriptor(ptr)
    end
  end
end
