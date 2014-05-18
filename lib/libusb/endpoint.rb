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
  class Endpoint < FFI::Struct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :bEndpointAddress, :uint8,
        :bmAttributes, :uint8,
        :wMaxPacketSize, :uint16,
        :bInterval, :uint8,
        :bRefresh, :uint8,
        :bSynchAddress, :uint8,
        :extra, :pointer,
        :extra_length, :int

    # Size of Descriptor in Bytes (7 bytes)
    def bLength
      self[:bLength]
    end

    # Descriptor type (0x05)
    def bDescriptorType
      self[:bDescriptorType]
    end

    # The address of the endpoint described by this descriptor.
    #
    # * Bits 0..3: Endpoint Number.
    # * Bits 4..6: Reserved. Set to Zero
    # * Bits 7: Direction 0 = Out, 1 = In (Ignored for Control Endpoints)
    #
    # @return [Integer]
    #
    # @see #endpoint_number
    # @see #direction
    def bEndpointAddress
      self[:bEndpointAddress]
    end

    # @return [Integer]
    def endpoint_number
      bEndpointAddress & 0b1111
    end

    # @return [Symbol]  Either +:in+ or +:out+
    def direction
      bEndpointAddress & ENDPOINT_IN == 0 ? :out : :in
    end

    # Attributes which apply to the endpoint when it is configured using the {Configuration#bConfigurationValue}.
    #
    # * Bits 1..0: Transfer Type
    #   * 00 = Control
    #   * 01 = Isochronous
    #   * 10 = Bulk
    #   * 11 = Interrupt
    # * Bits 7..2: are reserved. If Isochronous endpoint,
    # * Bits 3..2: Synchronisation Type (Iso Mode)
    #   * 00 = No Synchonisation
    #   * 01 = Asynchronous
    #   * 10 = Adaptive
    #   * 11 = Synchronous
    # * Bits 5..4: Usage Type (Iso Mode)
    #   * 00 = Data Endpoint
    #   * 01 = Feedback Endpoint
    #   * 10 = Explicit Feedback Data Endpoint
    #   * 11 = Reserved
    #
    # @return [Integer]
    #
    # @see #transfer_type
    # @see #usage_type
    # @see #synchronization_type
    def bmAttributes
      self[:bmAttributes]
    end

    TransferTypes = [:control, :isochronous, :bulk, :interrupt]
    # @return [Symbol]  One of {TransferTypes}
    def transfer_type
      TransferTypes[bmAttributes & 0b11]
    end

    SynchronizationTypes = [:no_synchronization, :asynchronous, :adaptive, :synchronous]
    # @return [Symbol]  One of {SynchronizationTypes}
    def synchronization_type
      return unless transfer_type == :isochronous
      SynchronizationTypes[(bmAttributes & 0b1100) >> 2]
    end

    UsageTypes = [:data, :feedback, :implicit_feedback, :unknown]
    # @return [Symbol]  One of {UsageTypes}
    def usage_type
      return unless transfer_type == :isochronous
      UsageTypes[(bmAttributes & 0b110000) >> 4]
    end

    # Maximum Packet Size this endpoint is capable of sending or receiving
    def wMaxPacketSize
      self[:wMaxPacketSize]
    end

    # Interval for polling endpoint data transfers. Value in frame counts.
    # Ignored for Bulk & Control Endpoints. Isochronous must equal 1 and field
    # may range from 1 to 255 for interrupt endpoints.
    #
    # The interval is respected by the kernel driver, so user mode processes
    # using libusb don't need to care about it.
    def bInterval
      self[:bInterval]
    end

    # For audio devices only: the rate at which synchronization feedback is provided.
    def bRefresh
      self[:bRefresh]
    end

    # For audio devices only: the address if the synch endpoint.
    def bSynchAddress
      self[:bSynchAddress]
    end

    # Extra descriptors.
    #
    # @return [String]
    def extra
      return if self[:extra].null?
      self[:extra].read_string(self[:extra_length])
    end

    def initialize(setting, *args)
      @setting = setting
      super(*args)
    end

    # @return [Setting] the setting this endpoint belongs to.
    attr_reader :setting

    def inspect
      type = [transfer_type, synchronization_type, usage_type].compact
      "\#<#{self.class} #{endpoint_number} #{direction} #{type.join(" ")}>"
    end

    # The {Device} this Endpoint belongs to.
    def device() self.setting.interface.configuration.device end
    # The {Configuration} this Endpoint belongs to.
    def configuration() self.setting.interface.configuration end
    # The {Interface} this Endpoint belongs to.
    def interface() self.setting.interface end

    def <=>(o)
      t = setting<=>o.setting
      t = bEndpointAddress<=>o.bEndpointAddress if t==0
      t
    end

    if Call.respond_to?(:libusb_get_ss_endpoint_companion_descriptor)

      # @method ss_companion
      # Get the endpoints superspeed endpoint companion descriptor (if any).
      #
      # Since libusb version 1.0.16.
      #
      # @return [SsCompanion]
      def ss_companion
        ep_comp = FFI::MemoryPointer.new :pointer
        res = Call.libusb_get_ss_endpoint_companion_descriptor(
          device.context.instance_variable_get(:@ctx),
          pointer,
          ep_comp
        )
        LIBUSB.raise_error res, "in libusb_get_ss_endpoint_companion_descriptor" if res!=0
        SsCompanion.new ep_comp.read_pointer
      end
    end
  end
end
