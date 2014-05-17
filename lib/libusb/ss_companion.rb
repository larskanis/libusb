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
  # A structure representing the superspeed endpoint companion descriptor.
  #
  # This descriptor is documented in section 9.6.7 of the USB 3.0 specification. All multiple-byte fields are represented in host-endian format.
  class SsCompanion < FFI::ManagedStruct
    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :bMaxBurst, :uint8,
        :bmAttributes, :uint8,
        :wBytesPerInterval, :uint16

    # Size of this descriptor (in bytes)
    def bLength
      self[:bLength]
    end

    # Descriptor type.
    #
    # Will have value LIBUSB::DT_SS_ENDPOINT_COMPANION in this context.
    def bDescriptorType
      self[:bDescriptorType]
    end

    # The maximum number of packets the endpoint can send or recieve as part of a burst.
    def bMaxBurst
      self[:bMaxBurst]
    end

    # In bulk EP: bits 4:0 represents the maximum number of streams the EP supports.
    #
    # In isochronous EP: bits 1:0 represents the Mult - a zero based value that determines the maximum number of packets within a service interval
    def bmAttributes
      self[:bmAttributes]
    end

    # The total number of bytes this EP will transfer every service interval.
    #
    # valid only for periodic EPs.
    def wBytesPerInterval
      self[:wBytesPerInterval]
    end

    def inspect
      "\#<#{self.class} burst: #{bMaxBurst} attrs: #{bmAttributes}>"
    end

    # @private
    def self.release(ptr)
      Call.libusb_free_ss_endpoint_companion_descriptor(ptr)
    end
  end
end
