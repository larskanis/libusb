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
  VERSION = "0.1.4"

  require 'libusb/call'
  require 'libusb/constants'
  require 'libusb/context'
  autoload :Configuration, 'libusb/configuration'
  autoload :DevHandle, 'libusb/dev_handle'
  autoload :Device, 'libusb/device'
  autoload :Endpoint, 'libusb/endpoint'
  autoload :Interface, 'libusb/interface'
  autoload :Setting, 'libusb/setting'
  %w[ Transfer BulkTransfer ControlTransfer InterruptTransfer IsoPacket IsochronousTransfer ].each do |klass|
    autoload klass, 'libusb/transfer'
  end
end
