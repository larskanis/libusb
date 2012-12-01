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
  # Class representing a handle on a USB device.
  #
  # A device handle is used to perform I/O and other operations. When finished
  # with a device handle, you should call DevHandle#close .
  class DevHandle
    # @private
    attr_reader :pHandle
    # @return [Device] the device this handle belongs to.
    attr_reader :device

    def initialize device, pHandle
      @device = device
      @pHandle = pHandle
      @bulk_transfer = @control_transfer = @interrupt_transfer = nil
    end

    # Close a device handle.
    #
    # Should be called on all open handles before your application exits.
    #
    # Internally, this function destroys the reference that was added by {Device#open}
    # on the given device.
    #
    # This is a non-blocking function; no requests are sent over the bus.
    def close
      Call.libusb_close(@pHandle)
    end

    def string_descriptor_ascii(index)
      pString = FFI::MemoryPointer.new 0x100
      res = Call.libusb_get_string_descriptor_ascii(@pHandle, index, pString, pString.size)
      LIBUSB.raise_error res, "in libusb_get_string_descriptor_ascii" unless res>=0
      pString.read_string(res)
    end

    # Claim an interface on a given device handle.
    #
    # You must claim the interface you wish to use before you can perform I/O on any
    # of its endpoints.
    #
    # It is legal to attempt to claim an already-claimed interface, in which case
    # libusb just returns without doing anything.
    #
    # Claiming of interfaces is a purely logical operation; it does not cause any
    # requests to be sent over the bus. Interface claiming is used to instruct the
    # underlying operating system that your application wishes to take ownership of
    # the interface.
    #
    # This is a non-blocking function.
    #
    # If called with a block, the device handle is passed through to the block
    # and the interface is released when the block has finished.
    #
    # @param [Interface, Fixnum] interface  the interface or it's bInterfaceNumber you wish to claim
    def claim_interface(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_claim_interface(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_claim_interface" if res!=0
      return self unless block_given?
      begin
        yield self
      ensure
        release_interface(interface)
      end
    end

    # Release an interface previously claimed with {DevHandle#claim_interface}.
    #
    # You should release all claimed interfaces before closing a device handle.
    #
    # This is a blocking function. A SET_INTERFACE control request will be sent to the
    # device, resetting interface state to the first alternate setting.
    #
    # @param [Interface, Fixnum] interface  the interface or it's bInterfaceNumber you
    #   claimed previously
    def release_interface(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_release_interface(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_release_interface" if res!=0
    end

    # Set the active configuration for a device.
    #
    # The operating system may or may not have already set an active configuration on
    # the device. It is up to your application to ensure the correct configuration is
    # selected before you attempt to claim interfaces and perform other operations.
    #
    # If you call this function on a device already configured with the selected
    # configuration, then this function will act as a lightweight device reset: it
    # will issue a SET_CONFIGURATION request using the current configuration, causing
    # most USB-related device state to be reset (altsetting reset to zero, endpoint
    # halts cleared, toggles reset).
    #
    # You cannot change/reset configuration if your application has claimed interfaces -
    # you should free them with {DevHandle#release_interface} first. You cannot
    # change/reset configuration if other applications or drivers have claimed
    # interfaces.
    #
    # A configuration value of +nil+ will put the device in unconfigured state. The USB
    # specifications state that a configuration value of 0 does this, however buggy
    # devices exist which actually have a configuration 0.
    #
    # You should always use this function rather than formulating your own
    # SET_CONFIGURATION control request. This is because the underlying operating
    # system needs to know when such changes happen.
    #
    # This is a blocking function.
    #
    # @param [Configuration, Fixnum] configuration   the configuration or it's
    #   bConfigurationValue you wish to activate, or +nil+ if you wish to put
    #   the device in unconfigured state
    def set_configuration(configuration)
      configuration = configuration.bConfigurationValue if configuration.respond_to? :bConfigurationValue
      res = Call.libusb_set_configuration(@pHandle, configuration || -1)
      LIBUSB.raise_error res, "in libusb_set_configuration" if res!=0
    end
    alias configuration= set_configuration

    # Activate an alternate setting for an interface.
    #
    # The interface must have been previously claimed with {DevHandle#claim_interface}.
    #
    # You should always use this function rather than formulating your own
    # SET_INTERFACE control request. This is because the underlying operating system
    # needs to know when such changes happen.
    #
    # This is a blocking function.
    #
    # @param [Setting, Fixnum] setting_or_interface_number  the alternate setting
    #   to activate or the bInterfaceNumber of the previously-claimed interface
    # @param [Fixnum, nil] alternate_setting  the bAlternateSetting of the alternate setting to activate
    #   (only if first param is a Fixnum)
    def set_interface_alt_setting(setting_or_interface_number, alternate_setting=nil)
      alternate_setting ||= setting_or_interface_number.bAlternateSetting if setting_or_interface_number.respond_to? :bAlternateSetting
      setting_or_interface_number = setting_or_interface_number.bInterfaceNumber if setting_or_interface_number.respond_to? :bInterfaceNumber
      res = Call.libusb_set_interface_alt_setting(@pHandle, setting_or_interface_number, alternate_setting)
      LIBUSB.raise_error res, "in libusb_set_interface_alt_setting" if res!=0
    end

    # Clear the halt/stall condition for an endpoint.
    #
    # Endpoints with halt status are unable to receive or transmit
    # data until the halt condition is stalled.
    #
    # You should cancel all pending transfers before attempting to
    # clear the halt condition.
    #
    # This is a blocking function.
    #
    # @param [Endpoint, Fixnum] endpoint  the endpoint in question or it's bEndpointAddress
    def clear_halt(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      res = Call.libusb_clear_halt(@pHandle, endpoint)
      LIBUSB.raise_error res, "in libusb_clear_halt" if res!=0
    end

    # Perform a USB port reset to reinitialize a device.
    #
    # The system will attempt to restore the previous configuration and
    # alternate settings after the reset has completed.
    #
    # If the reset fails, the descriptors change, or the previous
    # state cannot be restored, the device will appear to be disconnected
    # and reconnected. This means that the device handle is no longer
    # valid (you should close it) and rediscover the device. A Exception
    # of LIBUSB::ERROR_NOT_FOUND indicates when this is the case.
    #
    # This is a blocking function which usually incurs a noticeable delay.
    def reset_device
      res = Call.libusb_reset_device(@pHandle)
      LIBUSB.raise_error res, "in libusb_reset_device" if res!=0
    end

    # Determine if a kernel driver is active on an interface.
    #
    # If a kernel driver is active, you cannot claim the interface,
    # and libusb will be unable to perform I/O.
    #
    # @param [Interface, Fixnum] interface   the interface to check or it's bInterfaceNumber
    # @return [Boolean]
    def kernel_driver_active?(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_kernel_driver_active(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_kernel_driver_active" unless res>=0
      return res==1
    end

    # Detach a kernel driver from an interface.
    #
    # If successful, you will then be able to claim the interface and perform I/O.
    #
    # @param [Interface, Fixnum] interface    the interface to detach the driver
    #   from or it's bInterfaceNumber
    def detach_kernel_driver(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_detach_kernel_driver(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_detach_kernel_driver" if res!=0
    end

    # Re-attach an interface's kernel driver, which was previously detached
    # using {DevHandle#detach_kernel_driver}.
    #
    # @param [Interface, Fixnum] interface    the interface to attach the driver to
    def attach_kernel_driver(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_attach_kernel_driver(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_attach_kernel_driver" if res!=0
    end


    # Perform a USB bulk transfer.
    #
    # The direction of the transfer is inferred from the direction bits of the
    # endpoint address.
    #
    # For bulk reads, the +:dataIn+ param indicates the maximum length of data you are
    # expecting to receive. If less data arrives than expected, this function will
    # return that data.
    #
    # You should also check the returned number of bytes for bulk writes. Not all of the
    # data may have been written.
    #
    # Also check transferred bytes when dealing with a timeout error code. libusb may have
    # to split your transfer into a number of chunks to satisfy underlying O/S
    # requirements, meaning that the timeout may expire after the first few chunks
    # have completed. libusb is careful not to lose any data that may have been
    # transferred; do not assume that timeout conditions indicate a complete lack of
    # I/O.
    #
    # @param [Hash] args
    # @option args [Endpoint, Fixnum] :endpoint  the (address of a) valid endpoint to communicate with
    # @option args [String] :dataOut  the data to send with an outgoing transfer
    # @option args [Fixnum] :dataIn   the number of bytes expected to receive with an ingoing transfer
    # @option args [Fixnum] :timeout   timeout (in millseconds) that this function should wait before giving
    #   up due to no response being received. For an unlimited timeout, use value 0. Defaults to 1000 ms.
    #
    # @return [Fixnum] Number of bytes sent for an outgoing transfer
    # @return [String] Received data for an ingoing transfer
    def bulk_transfer(args={})
      timeout = args.delete(:timeout) || 1000
      endpoint = args.delete(:endpoint) || raise(ArgumentError, "no endpoint given")
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      if endpoint&ENDPOINT_IN != 0
        dataIn = args.delete(:dataIn) || raise(ArgumentError, "no :dataIn given for bulk read")
      else
        dataOut = args.delete(:dataOut) || raise(ArgumentError, "no :dataOut given for bulk write")
      end
      raise ArgumentError, "invalid params #{args.inspect}" unless args.empty?

      # reuse transfer struct to speed up transfer
      @bulk_transfer ||= BulkTransfer.new :dev_handle => self
      tr = @bulk_transfer
      tr.endpoint = endpoint
      tr.timeout = timeout
      if dataOut
        tr.buffer = dataOut
      else
        tr.alloc_buffer(dataIn)
      end

      tr.submit_and_wait!

      if dataOut
        tr.actual_length
      else
        tr.actual_buffer
      end
    end

    # Perform a USB interrupt transfer.
    #
    # The direction of the transfer is inferred from the direction bits of the
    # endpoint address.
    #
    # For interrupt reads, the +:dataIn+ param indicates the maximum length of data you
    # are expecting to receive. If less data arrives than expected, this function will
    # return that data.
    #
    # You should also check the returned number of bytes for interrupt writes. Not all of
    # the data may have been written.
    #
    # Also check transferred when dealing with a timeout error code. libusb may have
    # to split your transfer into a number of chunks to satisfy underlying O/S
    # requirements, meaning that the timeout may expire after the first few chunks
    # have completed. libusb is careful not to lose any data that may have been
    # transferred; do not assume that timeout conditions indicate a complete lack of
    # I/O.
    #
    # The default endpoint bInterval value is used as the polling interval.
    #
    # @param [Hash] args
    # @option args [Endpoint, Fixnum] :endpoint  the (address of a) valid endpoint to communicate with
    # @option args [String] :dataOut  the data to send with an outgoing transfer
    # @option args [Fixnum] :dataIn   the number of bytes expected to receive with an ingoing transfer
    # @option args [Fixnum] :timeout   timeout (in millseconds) that this function should wait before giving
    #   up due to no response being received. For an unlimited timeout, use value 0. Defaults to 1000 ms.
    #
    # @return [Fixnum] Number of bytes sent for an outgoing transfer
    # @return [String] Received data for an ingoing transfer
    def interrupt_transfer(args={})
      timeout = args.delete(:timeout) || 1000
      endpoint = args.delete(:endpoint) || raise(ArgumentError, "no endpoint given")
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      if endpoint&ENDPOINT_IN != 0
        dataIn = args.delete(:dataIn) || raise(ArgumentError, "no :dataIn given for interrupt read")
      else
        dataOut = args.delete(:dataOut) || raise(ArgumentError, "no :dataOut given for interrupt write")
      end
      raise ArgumentError, "invalid params #{args.inspect}" unless args.empty?

      # reuse transfer struct to speed up transfer
      @interrupt_transfer ||= InterruptTransfer.new :dev_handle => self
      tr = @interrupt_transfer
      tr.endpoint = endpoint
      tr.timeout = timeout
      if dataOut
        tr.buffer = dataOut
      else
        tr.alloc_buffer(dataIn)
      end

      tr.submit_and_wait!

      if dataOut
        tr.actual_length
      else
        tr.actual_buffer
      end
    end

    # Perform a USB control transfer.
    #
    # The direction of the transfer is inferred from the +:bmRequestType+ field of the
    # setup packet.
    #
    # @param [Hash] args
    # @option args [Fixnum] :bmRequestType   the request type field for the setup packet
    # @option args [Fixnum] :bRequest  the request field for the setup packet
    # @option args [Fixnum] :wValue  the value field for the setup packet
    # @option args [Fixnum] :wIndex  the index field for the setup packet
    # @option args [String] :dataOut  the data to send with an outgoing transfer, it
    #   is appended to the setup packet
    # @option args [Fixnum] :dataIn   the number of bytes expected to receive with an ingoing transfer
    #   (excluding setup packet)
    # @option args [Fixnum] :timeout   timeout (in millseconds) that this function should wait before giving
    #   up due to no response being received. For an unlimited timeout, use value 0. Defaults to 1000 ms.
    #
    # @return [Fixnum] Number of bytes sent (excluding setup packet) for outgoing transfer
    # @return [String] Received data (without setup packet) for ingoing transfer
    def control_transfer(args={})
      bmRequestType = args.delete(:bmRequestType) || raise(ArgumentError, "param :bmRequestType not given")
      bRequest = args.delete(:bRequest) || raise(ArgumentError, "param :bRequest not given")
      wValue = args.delete(:wValue) || raise(ArgumentError, "param :wValue not given")
      wIndex = args.delete(:wIndex) || raise(ArgumentError, "param :wIndex not given")
      timeout = args.delete(:timeout) || 1000
      if bmRequestType&ENDPOINT_IN != 0
        dataIn = args.delete(:dataIn) || 0
        dataOut = ''
      else
        dataOut = args.delete(:dataOut) || ''
      end
      raise ArgumentError, "invalid params #{args.inspect}" unless args.empty?

      # reuse transfer struct to speed up transfer
      @control_transfer ||= ControlTransfer.new :dev_handle => self
      tr = @control_transfer
      tr.timeout = timeout
      if dataIn
        setup_data = [bmRequestType, bRequest, wValue, wIndex, dataIn].pack('CCvvv')
        tr.alloc_buffer( dataIn + CONTROL_SETUP_SIZE, setup_data )
      else
        tr.buffer = [bmRequestType, bRequest, wValue, wIndex, dataOut.bytesize, dataOut].pack('CCvvva*')
      end

      tr.submit_and_wait!

      if dataIn
        tr.actual_buffer(CONTROL_SETUP_SIZE)
      else
        tr.actual_length
      end
    end
  end
end
