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
      @bulk_transfer.free_buffer if @bulk_transfer
      @interrupt_transfer.free_buffer if @interrupt_transfer
      @control_transfer.free_buffer if @control_transfer
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

    if Call.respond_to?(:libusb_alloc_streams)

      # @method alloc_streams
      #
      # Allocate up to num_streams usb bulk streams on the specified endpoints. This
      # function takes an array of endpoints rather then a single endpoint because
      # some protocols require that endpoints are setup with similar stream ids.
      # All endpoints passed in must belong to the same interface.
      #
      # Note this function may return less streams then requested. Also note that the
      # same number of streams are allocated for each endpoint in the endpoint array.
      #
      # Stream id 0 is reserved, and should not be used to communicate with devices.
      # If {alloc_streams} returns with a value of N, you may use stream ids
      # 1 to N.
      #
      # Available since libusb-1.0.19.
      #
      # @param [Fixnum] num_streams  number of streams to try to allocate
      # @param [Array<Fixnum>, Array<Endpoint>] endpoints  array of endpoints to allocate streams on
      # @return [Fixnum] number of streams allocated
      # @see #free_streams
      # @see BulkStreamTransfer
      def alloc_streams(num_streams, endpoints)
        pEndpoints = endpoints_as_ffi_bytes(endpoints)
        res = Call.libusb_alloc_streams(@pHandle, num_streams, pEndpoints, endpoints.length)
        LIBUSB.raise_error res, "in libusb_alloc_streams" unless res>=0
        res
      end

      # @method free_streams
      #
      # Free usb bulk streams allocated with {alloc_streams}
      #
      # Note streams are automatically free-ed when releasing an interface.
      #
      # Available since libusb-1.0.19.
      #
      # @param [Array<Fixnum>, Array<Endpoint>] endpoints  array of endpoints to free streams on
      # @see #alloc_streams
      def free_streams(endpoints)
        pEndpoints = endpoints_as_ffi_bytes(endpoints)
        res = Call.libusb_free_streams(@pHandle, pEndpoints, endpoints.length)
        LIBUSB.raise_error res, "in libusb_free_streams" unless res>=0
        nil
      end

    else

      def alloc_streams(num_streams, endpoints)
        raise NotImplementedError, "libusb-1.0.19+ is required for bulk stream transfers"
      end

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

    # @private
    if Call.respond_to?(:libusb_set_auto_detach_kernel_driver)

      # @method auto_detach_kernel_driver=
      # Enable/disable libusb's automatic kernel driver detachment.
      #
      # When this is enabled libusb will automatically detach the kernel driver on an
      # interface when claiming the interface, and attach it when releasing the
      # interface.
      #
      # Automatic kernel driver detachment is disabled on newly opened device handles by
      # default.
      #
      # On platforms which do not have CAP_SUPPORTS_DETACH_KERNEL_DRIVER this
      # function will return ERROR_NOT_SUPPORTED, and libusb will continue as if
      # this function was never called.
      #
      # Available since libusb-1.0.16.
      #
      # @param [Boolean] enable    whether to enable or disable auto kernel driver detachment
      #
      # @see LIBUSB.has_capability?
      def auto_detach_kernel_driver=(enable)
        res = Call.libusb_set_auto_detach_kernel_driver(@pHandle, enable ? 1 : 0)
        LIBUSB.raise_error res, "in libusb_set_auto_detach_kernel_driver" if res!=0
      end
    end

    # @private
    if Call.respond_to?(:libusb_get_bos_descriptor)

      # @method bos
      # Get a Binary Object Store (BOS) descriptor.
      #
      # This is a BLOCKING function, which will send requests to the device.
      #
      # Since libusb version 1.0.16.
      #
      # @return [Bos]
      def bos
        ctx = device.context.instance_variable_get(:@ctx)
        pp_desc = FFI::MemoryPointer.new :pointer
        res = Call.libusb_get_bos_descriptor(@pHandle, pp_desc)
        LIBUSB.raise_error res, "in libusb_get_bos_descriptor" if res!=0
        Bos.new(ctx, pp_desc.read_pointer)
      end
    end

    # Perform a USB bulk transfer.
    #
    # When called without a block, the transfer is done synchronously - so all events are handled
    # internally and the sent/received data will be returned after completion or an exception will be raised.
    #
    # When called with a block, the method returns immediately after submitting the transfer.
    # You then have to ensure, that {Context#handle_events} is called properly. As soon as the
    # transfer is completed, the block is called with the sent/received data in case of success
    # or the exception instance in case of failure.
    #
    # The direction of the transfer is inferred from the direction bits of the
    # endpoint address.
    #
    # For bulk reads, the +:dataIn+ param indicates the maximum length of data you are
    # expecting to receive. If less data arrives than expected, this function will
    # return that data.
    #
    # You should check the returned number of bytes for bulk writes. Not all of the
    # data may have been written.
    #
    # Also check {Error#transferred} when dealing with a timeout exception. libusb may have
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
    # @return [self]  When called with a block
    #
    # @yieldparam [String, Integer, LIBUSB::Error] result  result of the transfer is yielded to the block,
    #   when the asynchronous transfer has finished
    # @raise [ArgumentError, LIBUSB::Error] in case of failure
    def bulk_transfer(timeout: 1000,
                      endpoint:,
                      dataIn: nil,
                      dataOut: nil,
                      allow_device_memory: false,
                      &block)

      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      if endpoint&ENDPOINT_IN != 0
        dataIn || raise(ArgumentError, "no :dataIn given for bulk read")
      else
        dataOut || raise(ArgumentError, "no :dataOut given for bulk write")
      end

      # reuse transfer struct to speed up transfer
      @bulk_transfer ||= BulkTransfer.new dev_handle: self, allow_device_memory: allow_device_memory
      tr = @bulk_transfer
      tr.endpoint = endpoint
      tr.timeout = timeout
      if dataOut
        tr.buffer = dataOut
      else
        tr.alloc_buffer(dataIn)
      end

      submit_transfer(tr, dataIn, 0, &block)
    end

    # Perform a USB interrupt transfer.
    #
    # When called without a block, the transfer is done synchronously - so all events are handled
    # internally and the sent/received data will be returned after completion or an exception will be raised.
    #
    # When called with a block, the method returns immediately after submitting the transfer.
    # You then have to ensure, that {Context#handle_events} is called properly. As soon as the
    # transfer is completed, the block is called with the sent/received data in case of success
    # or the exception instance in case of failure.
    #
    # The direction of the transfer is inferred from the direction bits of the
    # endpoint address.
    #
    # For interrupt reads, the +:dataIn+ param indicates the maximum length of data you
    # are expecting to receive. If less data arrives than expected, this function will
    # return that data.
    #
    # You should check the returned number of bytes for interrupt writes. Not all of
    # the data may have been written.
    #
    # Also check {Error#transferred} when dealing with a timeout exception. libusb may have
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
    # @return [self]  When called with a block
    #
    # @yieldparam [String, Integer, LIBUSB::Error] result  result of the transfer is yielded to the block,
    #   when the asynchronous transfer has finished
    # @raise [ArgumentError, LIBUSB::Error] in case of failure
    def interrupt_transfer(timeout: 1000,
                           endpoint:,
                           dataIn: nil,
                           dataOut: nil,
                           allow_device_memory: false,
                           &block)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      if endpoint&ENDPOINT_IN != 0
        dataIn || raise(ArgumentError, "no :dataIn given for interrupt read")
      else
        dataOut || raise(ArgumentError, "no :dataOut given for interrupt write")
      end

      # reuse transfer struct to speed up transfer
      @interrupt_transfer ||= InterruptTransfer.new dev_handle: self, allow_device_memory: allow_device_memory
      tr = @interrupt_transfer
      tr.endpoint = endpoint
      tr.timeout = timeout
      if dataOut
        tr.buffer = dataOut
      else
        tr.alloc_buffer(dataIn)
      end

      submit_transfer(tr, dataIn, 0, &block)
    end

    # Perform a USB control transfer.
    #
    # When called without a block, the transfer is done synchronously - so all events are handled
    # internally and the sent/received data will be returned after completion or an exception will be raised.
    #
    # When called with a block, the method returns immediately after submitting the transfer.
    # You then have to ensure, that {Context#handle_events} is called properly. As soon as the
    # transfer is completed, the block is called with the sent/received data in case of success
    # or the exception instance in case of failure.
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
    # @return [self]  When called with a block
    #
    # @yieldparam [String, Integer, LIBUSB::Error] result  result of the transfer is yielded to the block,
    #   when the asynchronous transfer has finished
    # @raise [ArgumentError, LIBUSB::Error] in case of failure
    def control_transfer(bmRequestType:,
                         bRequest:,
                         wValue:,
                         wIndex:,
                         timeout: 1000,
                         dataIn: nil,
                         dataOut: nil,
                         allow_device_memory: false,
                         &block)

      if bmRequestType&ENDPOINT_IN != 0
        dataIn ||= 0
        dataOut = ''
      else
        dataOut ||= ''
      end

      # reuse transfer struct to speed up transfer
      @control_transfer ||= ControlTransfer.new dev_handle: self, allow_device_memory: allow_device_memory
      tr = @control_transfer
      tr.timeout = timeout
      if dataIn
        setup_data = [bmRequestType, bRequest, wValue, wIndex, dataIn].pack('CCvvv')
        tr.alloc_buffer( dataIn + CONTROL_SETUP_SIZE, setup_data )
      else
        tr.buffer = [bmRequestType, bRequest, wValue, wIndex, dataOut.bytesize, dataOut].pack('CCvvva*')
      end

      submit_transfer(tr, dataIn, CONTROL_SETUP_SIZE, &block)
    end

    private
    def submit_transfer(tr, dataIn, offset)
      if block_given?
        tr.submit! do
          res = dataIn ? tr.actual_buffer(offset) : tr.actual_length

          if tr.status==:TRANSFER_COMPLETED
            yield res
          else
            exception = Transfer::TransferStatusToError[tr.status] || ERROR_OTHER

            yield exception.new("error #{tr.status}", res)
          end
        end
        self
      else
        tr.submit_and_wait

        res = dataIn ? tr.actual_buffer(offset) : tr.actual_length

        unless tr.status==:TRANSFER_COMPLETED
          raise((Transfer::TransferStatusToError[tr.status] || ERROR_OTHER).new("error #{tr.status}", res))
        end
        res
      end
    end

    def endpoints_as_ffi_bytes(endpoints)
      pEndpoints = FFI::MemoryPointer.new :char, endpoints.length
      endpoints.each_with_index do |ep, epi|
        ep = ep.bEndpointAddress if ep.respond_to? :bEndpointAddress
        pEndpoints.put_uchar(epi, ep)
      end
      pEndpoints
    end
  end
end
