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
  # Class representing a libusb session.
  class Context
    # Initialize libusb context.
    def initialize
      m = FFI::MemoryPointer.new :pointer
      Call.libusb_init(m)
      @ctx = m.read_pointer
    end

    # Deinitialize libusb.
    #
    # Should be called after closing all open devices and before your application terminates.
    def exit
      Call.libusb_exit(@ctx)
    end

    # Set message verbosity.
    #
    # * Level 0: no messages ever printed by the library (default)
    # * Level 1: error messages are printed to stderr
    # * Level 2: warning and error messages are printed to stderr
    # * Level 3: informational messages are printed to stdout, warning and
    #   error messages are printed to stderr
    #
    # The default level is 0, which means no messages are ever printed. If you
    # choose to increase the message verbosity level, ensure that your
    # application does not close the stdout/stderr file descriptors.
    #
    # You are advised to set level 3. libusb is conservative with its message
    # logging and most of the time, will only log messages that explain error
    # conditions and other oddities. This will help you debug your software.
    #
    # If the LIBUSB_DEBUG environment variable was set when libusb was
    # initialized, this method does nothing: the message verbosity is
    # fixed to the value in the environment variable.
    #
    # If libusb was compiled without any message logging, this method
    # does nothing: you'll never get any messages.
    #
    # If libusb was compiled with verbose debug message logging, this
    # method does nothing: you'll always get messages from all levels.
    #
    # @param [Fixnum] level  debug level to set
    def debug=(level)
      Call.libusb_set_debug(@ctx, level)
    end

    def device_list
      pppDevs = FFI::MemoryPointer.new :pointer
      size = Call.libusb_get_device_list(@ctx, pppDevs)
      ppDevs = pppDevs.read_pointer
      pDevs = []
      size.times do |devi|
        pDev = ppDevs.get_pointer(devi*FFI.type_size(:pointer))
        pDevs << Device.new(self, pDev)
      end
      Call.libusb_free_device_list(ppDevs, 1)
      pDevs
    end
    private :device_list

    # Handle any pending events in blocking mode.
    #
    # This method must be called when libusb is running asynchronous transfers.
    # This gives libusb the opportunity to reap pending transfers,
    # invoke callbacks, etc.
    def handle_events
      res = Call.libusb_handle_events(@ctx)
      LIBUSB.raise_error res, "in libusb_handle_events" if res<0
    end

    def handle_events_timeout_completed
      t = Call::Timeval.new # FFI::MemoryPointer.new(Timeval)
      res = Call.libusb_handle_events_timeout_completed(@ctx, t.pointer, nil)
      LIBUSB.raise_error res, "in libusb_handle_events_timeout_completed" if res<0
    end

    def handle_events_timeout
      t = Call::Timeval.new # FFI::MemoryPointer.new(Timeval)
      res = Call.libusb_handle_events_timeout(@ctx, t.pointer)
      LIBUSB.raise_error res, "in libusb_handle_events_timeout" if res<0
    end

    # Obtain a list of devices currently attached to the USB system, optionally matching certain criteria.
    #
    # @param [Hash] filter_hash  A number of criteria can be defined in key-value pairs.
    #   Only devices that equal all given criterions will be returned. If a criterion is
    #   not specified or its value is +nil+, any device will match that criterion.
    #   The following criteria can be filtered:
    #   * <tt>:idVendor</tt>, <tt>:idProduct</tt> (+FixNum+) for matching vendor/product ID,
    #   * <tt>:bClass</tt>, <tt>:bSubClass</tt>, <tt>:bProtocol</tt> (+FixNum+) for the device type -
    #     Devices using CLASS_PER_INTERFACE will match, if any of the interfaces match.
    #   * <tt>:bcdUSB</tt>, <tt>:bcdDevice</tt>, <tt>:bMaxPacketSize0</tt> (+FixNum+) for the
    #     USB and device release numbers.
    #   Criteria can also specified as Array of several alternative values.
    #
    # @example
    #   # Return all devices of vendor 0x0ab1 where idProduct is 3 or 4:
    #   context.device :idVendor=>0x0ab1, :idProduct=>[0x0003, 0x0004]
    #
    # @return [Array<LIBUSB::Device>]
    def devices(filter_hash={})
      device_list.select do |dev|
        ( !filter_hash[:bClass] || (dev.bDeviceClass==CLASS_PER_INTERFACE ?
                             dev.settings.map(&:bInterfaceClass).&([filter_hash[:bClass]].flatten).any? :
                             [filter_hash[:bClass]].flatten.include?(dev.bDeviceClass))) &&
        ( !filter_hash[:bSubClass] || (dev.bDeviceClass==CLASS_PER_INTERFACE ?
                             dev.settings.map(&:bInterfaceSubClass).&([filter_hash[:bSubClass]].flatten).any? :
                             [filter_hash[:bSubClass]].flatten.include?(dev.bDeviceSubClass))) &&
        ( !filter_hash[:bProtocol] || (dev.bDeviceClass==CLASS_PER_INTERFACE ?
                             dev.settings.map(&:bInterfaceProtocol).&([filter_hash[:bProtocol]].flatten).any? :
                             [filter_hash[:bProtocol]].flatten.include?(dev.bDeviceProtocol))) &&
        ( !filter_hash[:bMaxPacketSize0] || [filter_hash[:bMaxPacketSize0]].flatten.include?(dev.bMaxPacketSize0) ) &&
        ( !filter_hash[:idVendor] || [filter_hash[:idVendor]].flatten.include?(dev.idVendor) ) &&
        ( !filter_hash[:idProduct] || [filter_hash[:idProduct]].flatten.include?(dev.idProduct) ) &&
        ( !filter_hash[:bcdUSB] || [filter_hash[:bcdUSB]].flatten.include?(dev.bcdUSB) ) &&
        ( !filter_hash[:bcdDevice] || [filter_hash[:bcdDevice]].flatten.include?(dev.bcdDevice) )
      end
    end
  end
end
