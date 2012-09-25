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

module LIBUSB
  VERSION = "0.2.1"

  require 'libusb/call'
  require 'libusb/constants'
  require 'libusb/context'
  autoload :Version, 'libusb/version'
  autoload :Configuration, 'libusb/configuration'
  autoload :DevHandle, 'libusb/dev_handle'
  autoload :Device, 'libusb/device'
  autoload :Endpoint, 'libusb/endpoint'
  autoload :Interface, 'libusb/interface'
  autoload :Setting, 'libusb/setting'
  %w[ Transfer BulkTransfer ControlTransfer InterruptTransfer IsoPacket IsochronousTransfer ].each do |klass|
    autoload klass, 'libusb/transfer'
  end

  if Call.respond_to?(:libusb_get_version)
    # Get version of the underlying libusb library.
    # Available since libusb-1.0.10.
    # @return [Version]  version object
    def self.version
      Version.new(Call.libusb_get_version)
    end
  end

  if Call.respond_to?(:libusb_has_capability)
    # Check at runtime if the loaded library has a given capability.
    # Available since libusb-1.0.9.
    # @param [Symbol] capability  the {Call::Capabilities Capabilities} symbol to check for
    # @return [Boolean]  +true+ if the running library has the capability, +false+ otherwise
    def self.has_capability?(capability)
      r = Call.libusb_has_capability(capability)
      return r != 0
    end
  end
end
