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
  class Configuration < FFI::ManagedStruct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :wTotalLength, :uint16,
        :bNumInterfaces, :uint8,
        :bConfigurationValue, :uint8,
        :iConfiguration, :uint8,
        :bmAttributes, :uint8,
        :bMaxPower, :uint8,
        :interface, :pointer,
        :extra, :pointer,
        :extra_length, :int

    # Size of this descriptor (in bytes).
    def bLength
      self[:bLength]
    end

    # Descriptor type (0x02)
    def bDescriptorType
      self[:bDescriptorType]
    end

    # Total length of data returned for this configuration.
    def wTotalLength
      self[:wTotalLength]
    end

    # Number of interfaces supported by this configuration.
    def bNumInterfaces
      self[:bNumInterfaces]
    end

    # Identifier value for this configuration.
    def bConfigurationValue
      self[:bConfigurationValue]
    end

    # Index of string descriptor describing this configuration.
    def iConfiguration
      self[:iConfiguration]
    end

    # Configuration characteristics.
    #
    # * Bit 7: Reserved, set to 1. (USB 1.0 Bus Powered)
    # * Bit 6: Self Powered
    # * Bit 5: Remote Wakeup
    # * Bit 4..0: Reserved, set to 0.
    #
    # @return [Integer]
    def bmAttributes
      self[:bmAttributes]
    end

    # Maximum power consumption of the USB device from this bus in this configuration when the device is fully opreation.
    #
    # @return [Integer] Maximum Power Consumption in 2mA units
    def bMaxPower
      self[:bMaxPower]
    end

    # @deprecated Use {#bMaxPower} instead.
    alias maxPower bMaxPower


    # Extra descriptors.
    #
    # @return [String]
    def extra
      return if self[:extra].null?
      self[:extra].read_string(self[:extra_length])
    end

    def initialize(device, *args)
      @device = device
      super(*args)
    end

    def self.release(ptr)
      Call.libusb_free_config_descriptor(ptr)
    end

    # @return [Device] the device this configuration belongs to.
    attr_reader :device

    def interfaces
      ifs = []
      self[:bNumInterfaces].times do |i|
        ifs << Interface.new(self, self[:interface] + i*Interface.size)
      end
      return ifs
    end

    def inspect
      attrs = []
      attrs << self.bConfigurationValue.to_s
      bits = self.bmAttributes
      attrs << "SelfPowered" if (bits & 0b1000000) != 0
      attrs << "RemoteWakeup" if (bits & 0b100000) != 0
      desc = self.description
      attrs << desc if desc != '?'
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    # Return name of this configuration as String.
    def description
      return @description if defined? @description
      @description = device.try_string_descriptor_ascii(self.iConfiguration)
    end

    # Return all interface decriptions of the configuration as Array of {Setting}s.
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    # Return all endpoints of all interfaces of the configuration as Array of {Endpoint}s.
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = device<=>o.device
      t = bConfigurationValue<=>o.bConfigurationValue if t==0
      t
    end
  end
end
