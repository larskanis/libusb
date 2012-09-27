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
  class Interface < FFI::Struct
    include Comparable

    layout :altsetting, :pointer,
        :num_altsetting, :int

    # Number of this interface.
    def bInterfaceNumber
      settings.first.bInterfaceNumber
    end

    def initialize(configuration, *args)
      @configuration = configuration
      super(*args)
    end

    # @return [Configuration] the configuration this interface belongs to.
    attr_reader :configuration

    def alt_settings
      ifs = []
      self[:num_altsetting].times do |i|
        ifs << Setting.new(self, self[:altsetting] + i*Setting.size)
      end
      return ifs
    end
    alias settings alt_settings

    def inspect
      "\#<#{self.class} #{bInterfaceNumber}>"
    end

    # The {Device} this Interface belongs to.
    def device() self.configuration.device end
    # Return all endpoints of all alternative settings as Array of {Endpoint}s.
    def endpoints() self.alt_settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      configuration<=>o.configuration
    end
  end
end
