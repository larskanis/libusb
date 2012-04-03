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
  class Setting < FFI::Struct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :bInterfaceNumber, :uint8,
        :bAlternateSetting, :uint8,
        :bNumEndpoints, :uint8,
        :bInterfaceClass, :uint8,
        :bInterfaceSubClass, :uint8,
        :bInterfaceProtocol, :uint8,
        :iInterface, :uint8,
        :endpoint, :pointer,
        :extra, :pointer,
        :extra_length, :int

    # Size of this descriptor (in bytes).
    def bLength
      self[:bLength]
    end

    # Descriptor type (0x04)
    def bDescriptorType
      self[:bDescriptorType]
    end

    # Number of this interface.
    def bInterfaceNumber
      self[:bInterfaceNumber]
    end

    # Value used to select this alternate setting for this interface.
    def bAlternateSetting
      self[:bAlternateSetting]
    end

    # Number of endpoints used by this interface (excluding the control endpoint).
    def bNumEndpoints
      self[:bNumEndpoints]
    end

    # USB-IF class code for this interface.
    def bInterfaceClass
      self[:bInterfaceClass]
    end

    # USB-IF subclass code for this interface, qualified by the {bInterfaceClass} value.
    def bInterfaceSubClass
      self[:bInterfaceSubClass]
    end

    # USB-IF protocol code for this interface, qualified by the {bInterfaceClass} and {bInterfaceSubClass} values.
    def bInterfaceProtocol
      self[:bInterfaceProtocol]
    end

    # Index of string descriptor describing this interface.
    def iInterface
      self[:iInterface]
    end

    # Extra descriptors.
    #
    # @return [String]
    def extra
      return if self[:extra].null?
      self[:extra].read_string(self[:extra_length])
    end

    def initialize(interface, *args)
      @interface = interface
      super(*args)
    end

    # @return [Interface] the interface this setting belongs to.
    attr_reader :interface

    def endpoints
      ifs = []
      self[:bNumEndpoints].times do |i|
        ifs << Endpoint.new(self, self[:endpoint] + i*Endpoint.size)
      end
      return ifs
    end

    def inspect
      attrs = []
      attrs << self.bAlternateSetting.to_s
      devclass = LIBUSB.dev_string(self.bInterfaceClass, self.bInterfaceSubClass, self.bInterfaceProtocol)
      attrs << devclass
      desc = self.description
      attrs << desc if desc != '?'
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    # Return name of this interface as String.
    def description
      return @description if defined? @description
      @description = device.try_string_descriptor_ascii(self.iInterface)
    end

    # The {Device} this Setting belongs to.
    def device() self.interface.configuration.device end
    # The {Configuration} this Setting belongs to.
    def configuration() self.interface.configuration end

    def <=>(o)
      t = interface<=>o.interface
      t = bInterfaceNumber<=>o.bInterfaceNumber if t==0
      t = bAlternateSetting<=>o.bAlternateSetting if t==0
      t
    end
  end
end
