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
  # Class representing a USB device detected on the system.
  #
  # Devices of the system can be obtained with {Context#devices} .
  class Device
    include Comparable
    include ContextReference

    # @return [Context] the context this device belongs to.
    attr_reader :context

    def initialize context, pDev
      @context = context
      @pDev = pDev
      register_context(context.instance_variable_get(:@ctx), :libusb_unref_device)
      Call.libusb_ref_device(pDev)

      @pDevDesc = Call::DeviceDescriptor.new
      res = Call.libusb_get_device_descriptor(@pDev, @pDevDesc)
      LIBUSB.raise_error res, "in libusb_get_device_descriptor" if res!=0
    end

    # The pointer for ContextReference
    private def pointer
      @pDev
    end

    # Open the device and obtain a device handle.
    #
    # A handle allows you to perform I/O on the device in question.
    # This is a non-blocking function; no requests are sent over the bus.
    #
    # If called with a block, the handle is passed to the block
    # and is closed when the block has finished.
    #
    # You need proper device access:
    # * Linux: read+write permissions to <tt>/dev/bus/usb/<bus>/<dev></tt>
    # * Windows: by installing a WinUSB-driver for the device (see {file:README.rdoc#Usage_on_Windows} )
    #
    # @return [DevHandle] Handle to the device.
    def open
      ppHandle = FFI::MemoryPointer.new :pointer
      res = Call.libusb_open(@pDev, ppHandle)
      LIBUSB.raise_error res, "in libusb_open" if res!=0
      handle = DevHandle.new self, ppHandle.read_pointer
      return handle unless block_given?
      begin
        yield handle
      ensure
        handle.close
      end
    end

    # Open the device and claim an interface.
    #
    # This is a convenience method to {Device#open} and {DevHandle#claim_interface}.
    # Must be called with a block. When the block has finished, the interface
    # will be released and the device will be closed.
    #
    # @param [Interface, Fixnum] interface  the interface or it's bInterfaceNumber you wish to claim
    def open_interface(interface)
      open do |dev|
        dev.claim_interface(interface) do
          yield dev
        end
      end
    end

    # Get the number of the bus that a device is connected to.
    def bus_number
      Call.libusb_get_bus_number(@pDev)
    end

    # Get the address of the device on the bus it is connected to.
    def device_address
      Call.libusb_get_device_address(@pDev)
    end

    if Call.respond_to?(:libusb_get_port_number)
      # Get the number of the port that a device is connected to.
      # Available since libusb-1.0.12.
      #
      # @return [Fixnum, nil]  the port number (+nil+ if not available)
      # @see #port_numbers
      def port_number
        r = Call.libusb_get_port_number(@pDev)
        r==0 ? nil : r
      end

      # Get the the parent from the specified device [EXPERIMENTAL].
      # Available since libusb-1.0.12.
      #
      # @return [Device, nil]  the device parent or +nil+ if not available
      # @see #port_numbers
      def parent
        pppDevs = FFI::MemoryPointer.new :pointer
        Call.libusb_get_device_list(@context.instance_variable_get(:@ctx), pppDevs)
        ppDevs = pppDevs.read_pointer
        pParent = Call.libusb_get_parent(@pDev)
        parent = pParent.null? ? nil : Device.new(@context, pParent)
        Call.libusb_free_device_list(ppDevs, 1)
        parent
      end

      # Get the list of all port numbers from root for the specified device.
      # Available since libusb-1.0.12.
      #
      # @return [Array<Fixnum>]
      # @see #parent
      # @see #port_number
      def port_numbers
        # As per the USB 3.0 specs, the current maximum limit for the depth is 7.
        path_len = 7
        pPath = FFI::MemoryPointer.new :pointer, path_len

        l = if Call.respond_to?(:libusb_get_port_numbers)
          Call.libusb_get_port_numbers(@pDev, pPath, path_len)
        else
          Call.libusb_get_port_path(@context.instance_variable_get(:@ctx), @pDev, pPath, path_len)
        end
        pPath.read_array_of_uint8(l)
      end
      alias port_path port_numbers
    end

    if Call.respond_to?(:libusb_get_device_speed)
      # Get the negotiated connection speed for a device.
      # Available since libusb-1.0.9.
      #
      # @return [Symbol]  a {Call::Speeds Speeds} symbol, where +:SPEED_UNKNOWN+ means that
      #   the OS doesn't know or doesn't support returning the negotiated speed.
      def device_speed
        Call.libusb_get_device_speed(@pDev)
      end
    end

    # Convenience function to retrieve the wMaxPacketSize value for a
    # particular endpoint in the active device configuration.
    #
    # @param [Endpoint, Fixnum] endpoint  (address of) the endpoint in question
    # @return [Fixnum]  the wMaxPacketSize value
    def max_packet_size(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      res = Call.libusb_get_max_packet_size(@pDev, endpoint)
      LIBUSB.raise_error res, "in libusb_get_max_packet_size" unless res>=0
      res
    end

    if Call.respond_to?(:libusb_get_max_alt_packet_size)

      # Calculate the maximum packet size which a specific endpoint is capable of
      # sending or receiving in the duration of 1 microframe
      #
      # Only the active configuration is examined. The calculation is based on the
      # wMaxPacketSize field in the endpoint descriptor as described in section
      # 9.6.6 in the USB 2.0 specifications.
      #
      # If acting on an isochronous or interrupt endpoint, this function will
      # multiply the value found in bits 0:10 by the number of transactions per
      # microframe (determined by bits 11:12). Otherwise, this function just
      # returns the numeric value found in bits 0:10. For USB 3.0 device, it
      # will attempts to retrieve the Endpoint Companion Descriptor to return
      # wBytesPerInterval.
      #
      # This function is useful for setting up isochronous transfers, for example
      # you might pass the return value from this function to
      # +IsochronousTransfer.packet_lengths=+ in order to set the length field of every
      # isochronous packet in a transfer.
      #
      # Available since libusb-1.0.27.
      #
      # @param [Interface, Fixnum] interface  the interface or its bInterfaceNumber of the interface the endpoint belongs to
      # @param [Setting, Fixnum] alternate_setting  the alternate setting or its bAlternateSetting
      # @param [Endpoint, Fixnum] endpoint  (address of) the endpoint in question
      # @return [Fixnum]  the maximum packet size which can be sent/received on this endpoint
      # @see max_iso_packet_size
      def max_alt_packet_size(interface, alternate_setting, endpoint)
        interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
        alternate_setting = alternate_setting.bAlternateSetting if alternate_setting.respond_to? :bAlternateSetting
        endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
        res = Call.libusb_get_max_alt_packet_size(@pDev, interface, alternate_setting, endpoint)
        LIBUSB.raise_error res, "in libusb_get_max_alt_packet_size" unless res>=0
        res
      end
    end

    # Calculate the maximum packet size which a specific endpoint is capable is
    # sending or receiving in the duration of 1 microframe.
    #
    # Only the active configution is examined. The calculation is based on the
    # wMaxPacketSize field in the endpoint descriptor as described in section 9.6.6
    # in the USB 2.0 specifications.
    #
    # If acting on an isochronous or interrupt endpoint, this function will
    # multiply the value found in bits 0:10 by the number of transactions per
    # microframe (determined by bits 11:12). Otherwise, this function just returns
    # the numeric value found in bits 0:10.
    #
    # This function is useful for setting up isochronous transfers, for example
    # you might use the return value from this function to call
    # IsoPacket#alloc_buffer in order to set the length field
    # of an isochronous packet in a transfer.
    #
    # @param [Endpoint, Fixnum] endpoint  (address of) the endpoint in question
    # @return [Fixnum] the maximum packet size which can be sent/received on this endpoint
    # @see max_alt_packet_size
    def max_iso_packet_size(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      res = Call.libusb_get_max_iso_packet_size(@pDev, endpoint)
      LIBUSB.raise_error res, "in libusb_get_max_iso_packet_size" unless res>=0
      res
    end

    # Obtain a config descriptor of the device.
    #
    # @param [Fixnum] index  number of the config descriptor
    # @return Configuration
    def config_descriptor(index)
      ppConfig = FFI::MemoryPointer.new :pointer
      res = Call.libusb_get_config_descriptor(@pDev, index, ppConfig)
      LIBUSB.raise_error res, "in libusb_get_config_descriptor" if res!=0
      pConfig = ppConfig.read_pointer
      config = Configuration.new(self, pConfig)
      config
    end

    # Size of the Descriptor in Bytes (18 bytes)
    def bLength
      @pDevDesc[:bLength]
    end

    # Device Descriptor (0x01)
    def bDescriptorType
      @pDevDesc[:bDescriptorType]
    end

    # USB specification release number which device complies too
    #
    # @return [Integer] in binary-coded decimal
    def bcdUSB
      @pDevDesc[:bcdUSB]
    end

    # USB-IF class code for the device (Assigned by USB Org)
    #
    # * If equal to 0x00, each interface specifies it's own class code
    # * If equal to 0xFF, the class code is vendor specified
    # * Otherwise field is valid Class Code
    def bDeviceClass
      @pDevDesc[:bDeviceClass]
    end

    # USB-IF subclass code for the device, qualified by the {Device#bDeviceClass}
    # value (Assigned by USB Org)
    def bDeviceSubClass
      @pDevDesc[:bDeviceSubClass]
    end

    # USB-IF protocol code for the device, qualified by the {Device#bDeviceClass}
    # and {Device#bDeviceSubClass} values (Assigned by USB Org)
    def bDeviceProtocol
      @pDevDesc[:bDeviceProtocol]
    end

    # Maximum Packet Size for Endpoint 0. Valid Sizes are 8, 16, 32, 64
    def bMaxPacketSize0
      @pDevDesc[:bMaxPacketSize0]
    end

    # USB-IF vendor ID (Assigned by USB Org)
    def idVendor
      @pDevDesc[:idVendor]
    end

    # USB-IF product ID (Assigned by Manufacturer)
    def idProduct
      @pDevDesc[:idProduct]
    end

    # Device release number in binary-coded decimal.
    def bcdDevice
      @pDevDesc[:bcdDevice]
    end

    # Index of string descriptor describing manufacturer.
    def iManufacturer
      @pDevDesc[:iManufacturer]
    end

    # Index of string descriptor describing product.
    def iProduct
      @pDevDesc[:iProduct]
    end

    # Index of string descriptor containing device serial number.
    def iSerialNumber
      @pDevDesc[:iSerialNumber]
    end

    # Number of Possible Configurations
    def bNumConfigurations
      @pDevDesc[:bNumConfigurations]
    end


    def inspect
      attrs = []
      attrs << "#{self.bus_number}/#{self.device_address}"
      attrs << ("%04x:%04x" % [self.idVendor, self.idProduct])
      attrs << self.manufacturer
      attrs << self.product
      attrs << self.serial_number
      if self.bDeviceClass == LIBUSB::CLASS_PER_INTERFACE
        devclass = self.settings.map {|i|
          LIBUSB.dev_string(i.bInterfaceClass, i.bInterfaceSubClass, i.bInterfaceProtocol)
        }.join(", ")
      else
        devclass = LIBUSB.dev_string(self.bDeviceClass, self.bDeviceSubClass, self.bDeviceProtocol)
      end
      attrs << "(#{devclass})"
      attrs.compact!
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    def try_string_descriptor_ascii(i)
      begin
        open{|h| h.string_descriptor_ascii(i) }
      rescue
        "?"
      end
    end

    # Return manufacturer of the device
    # @return String
    def manufacturer
      return @manufacturer if defined? @manufacturer
      @manufacturer = try_string_descriptor_ascii(self.iManufacturer)
      @manufacturer.strip! if @manufacturer
      @manufacturer
    end

    # Return product name of the device.
    # @return String
    def product
      return @product if defined? @product
      @product = try_string_descriptor_ascii(self.iProduct)
      @product.strip! if @product
      @product
    end

    # Return serial number of the device.
    # @return String
    def serial_number
      return @serial_number if defined? @serial_number
      @serial_number = try_string_descriptor_ascii(self.iSerialNumber)
      @serial_number.strip! if @serial_number
      @serial_number
    end

    # Return configurations of the device.
    # @return [Array<Configuration>]
    def configurations
      configs = []
      bNumConfigurations.times do |config_index|
        begin
          configs << config_descriptor(config_index)
        rescue RuntimeError
          # On Windows some devices don't return it's configuration.
        end
      end
      configs
    end

    # Return all interfaces of this device.
    # @return [Array<Interface>]
    def interfaces() self.configurations.map {|d| d.interfaces }.flatten end
    # Return all interface decriptions of this device.
    # @return [Array<Setting>]
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    # Return all endpoints of all interfaces of this device.
    # @return [Array<Endpoint>]
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = bus_number<=>o.bus_number
      t = device_address<=>o.device_address if t==0
      t
    end
  end
end
