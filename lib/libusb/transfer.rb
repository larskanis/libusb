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
  # Abstract base class for USB transfers. Use
  # {ControlTransfer}, {BulkTransfer}, {InterruptTransfer}, {IsochronousTransfer}
  # to do transfers.
  #
  # There are convenience methods for {DevHandle#bulk_transfer}, {DevHandle#control_transfer}
  # and {DevHandle#interrupt_transfer}, that fit for most use cases.
  # Using {Transfer} derived classes directly, however, is needed for isochronous transfers and
  # allows a more advanced buffer management.
  class Transfer
    def initialize(args={})
      args.each{|k,v| send("#{k}=", v) }
      @buffer = nil
      @completion_flag = Context::CompletionFlag.new
    end
    private :initialize

    # Set the handle for the device to communicate with.
    def dev_handle=(dev)
      @dev_handle = dev
      @transfer[:dev_handle] = @dev_handle.pHandle
    end

    # Timeout for this transfer in millseconds.
    #
    # A value of 0 indicates no timeout.
    def timeout=(value)
      @transfer[:timeout] = value
    end

    # Set the address of a valid endpoint to communicate with.
    def endpoint=(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      @transfer[:endpoint] = endpoint
    end

    # Set output data that should be sent.
    def buffer=(data)
      if !@buffer || data.bytesize>@buffer.size
        free_buffer
        @buffer = FFI::MemoryPointer.new(data.bytesize, 1, false)
      end
      @buffer.put_bytes(0, data)
      @transfer[:buffer] = @buffer
      @transfer[:length] = data.bytesize
    end

    # Retrieve the current data buffer.
    def buffer
      @transfer[:buffer].read_string(@transfer[:length])
    end

    # Clear the current data buffer.
    def free_buffer
      if @buffer
        @buffer.free
        @buffer = nil
        @transfer[:buffer] = nil
        @transfer[:length] = 0
      end
    end

    # Allocate +len+ bytes of data buffer for input transfer.
    #
    # @param [Fixnum]  len  Number of bytes to allocate
    # @param [String, nil] data  some data to initialize the buffer with
    def alloc_buffer(len, data=nil)
      if !@buffer || len>@buffer.size
        free_buffer
        @buffer = FFI::MemoryPointer.new(len, 1, false)
      end
      @buffer.put_bytes(0, data) if data
      @transfer[:buffer] = @buffer
      @transfer[:length] = len
    end

    # The number of bytes actually transferred.
    def actual_length
      @transfer[:actual_length]
    end

    # Retrieve the data actually transferred.
    #
    # @param [Fixnum] offset  optional offset of the retrieved data in the buffer.
    def actual_buffer(offset=0)
      @transfer[:buffer].get_bytes(offset, @transfer[:actual_length])
    end

    # Set the block that will be invoked when the transfer completes,
    # fails, or is cancelled.
    #
    # @param [Proc] proc  The block that should be called
    def callback=(proc)
      # Save proc to instance variable so that GC doesn't free
      # the proc object before the transfer.
      @callback_proc = proc do |pTrans|
        proc.call(self)
      end
      @transfer[:callback] = @callback_proc
    end

    # The status of the transfer.
    #
    # Only for use within transfer callback function or after the callback was called.
    #
    # If this is an isochronous transfer, this field may read :TRANSFER_COMPLETED even if there
    # were errors in the frames. Use the status field in each packet to determine if
    # errors occurred.
    def status
      @transfer[:status]
    end

    # Submit a transfer.
    #
    # This function will fire off the USB transfer and then return immediately.
    # This method can be called with block. It is called when the transfer completes,
    # fails, or is cancelled.
    def submit!(&block)
      self.callback = block if block_given?

#       puts "submit transfer #{@transfer.inspect} buffer: #{@transfer[:buffer].inspect} length: #{@transfer[:length].inspect} status: #{@transfer[:status].inspect} callback: #{@transfer[:callback].inspect} dev_handle: #{@transfer[:dev_handle].inspect}"

      res = Call.libusb_submit_transfer( @transfer )
      LIBUSB.raise_error res, "in libusb_submit_transfer" if res!=0
    end

    # Asynchronously cancel a previously submitted transfer.
    #
    # This function returns immediately, but this does not indicate cancellation is
    # complete. Your callback function will be invoked at some later time with a
    # transfer status of :TRANSFER_CANCELLED.
    def cancel!
      res = Call.libusb_cancel_transfer( @transfer )
      LIBUSB.raise_error res, "in libusb_cancel_transfer" if res!=0
    end

    TransferStatusToError = {
      :TRANSFER_ERROR => LIBUSB::ERROR_IO,
      :TRANSFER_TIMED_OUT => LIBUSB::ERROR_TIMEOUT,
      :TRANSFER_CANCELLED => LIBUSB::ERROR_INTERRUPTED,
      :TRANSFER_STALL => LIBUSB::ERROR_PIPE,
      :TRANSFER_NO_DEVICE => LIBUSB::ERROR_NO_DEVICE,
      :TRANSFER_OVERFLOW => LIBUSB::ERROR_OVERFLOW,
    }

    # Submit the transfer and wait until the transfer completes or fails.
    #
    # Inspect {#status} to check for transfer errors.
    def submit_and_wait
      @completion_flag.completed = false
      submit! do |tr2|
        @completion_flag.completed = true
      end

      until @completion_flag.completed?
        begin
          @dev_handle.device.context.handle_events nil, @completion_flag
        rescue ERROR_INTERRUPTED
          next
        rescue LIBUSB::Error
          cancel!
          until @completion_flag.completed?
            @dev_handle.device.context.handle_events nil, @completion_flag
          end
          raise
        end
      end
    end

    # Submit the transfer and wait until the transfer completes or fails.
    #
    # A proper {LIBUSB::Error} is raised, in case the transfer did not complete.
    def submit_and_wait!
      submit_and_wait

      raise( TransferStatusToError[status] || ERROR_OTHER, "error #{status}") unless status==:TRANSFER_COMPLETED
    end
  end

  class BulkTransfer < Transfer
    def initialize(args={})
      @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
      @transfer[:type] = TRANSFER_TYPE_BULK
      @transfer[:timeout] = 1000
      super
    end
  end

  if Call.respond_to?(:libusb_transfer_get_stream_id)

    # Transfer class for USB bulk transfers using USB-3.0 streams.
    #
    # @see DevHandle#alloc_streams
    #
    # Available since libusb-1.0.19.
    class BulkStreamTransfer < Transfer
      def initialize(args={})
        @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
        @transfer[:type] = TRANSFER_TYPE_BULK_STREAM
        @transfer[:timeout] = 1000
        super
      end

      # Set a transfers bulk stream id.
      #
      # @param [Fixnum] stream_id  the stream id to set
      def stream_id=(v)
        Call.libusb_transfer_set_stream_id(@transfer, v)
        v
      end

      # Get a transfers bulk stream id.
      #
      # Since version 1.0.19.
      #
      # \returns [Fixnum] the stream id for the transfer
      def stream_id
        Call.libusb_transfer_get_stream_id(@transfer)
      end
    end
  end

  class ControlTransfer < Transfer
    def initialize(args={})
      @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
      @transfer[:type] = TRANSFER_TYPE_CONTROL
      @transfer[:timeout] = 1000
      super
    end
  end

  class InterruptTransfer < Transfer
    def initialize(args={})
      @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
      @transfer[:type] = TRANSFER_TYPE_INTERRUPT
      @transfer[:timeout] = 1000
      super
    end
  end

  class IsoPacket
    def initialize(ptr, pkg_nr)
      @packet = Call::IsoPacketDescriptor.new ptr
      @pkg_nr = pkg_nr
    end

    def status
      @packet[:status]
    end

    def length
      @packet[:length]
    end
    def length=(len)
      @packet[:length] = len
    end

    def actual_length
      @packet[:actual_length]
    end
  end

  class IsochronousTransfer < Transfer
    def initialize(num_packets, args={})
      @ptr = Call.libusb_alloc_transfer(num_packets)
      @transfer = Call::Transfer.new @ptr
      @transfer[:type] = TRANSFER_TYPE_ISOCHRONOUS
      @transfer[:timeout] = 1000
      @transfer[:num_iso_packets] = num_packets
      super(args)
    end

    def num_packets
      @transfer[:num_iso_packets]
    end
    def num_packets=(number)
      @transfer[:num_iso_packets] = number
    end

    def [](nr)
      IsoPacket.new( @ptr + Call::Transfer.size + nr*Call::IsoPacketDescriptor.size, nr)
    end

    # Convenience function to set the length of all packets in an
    # isochronous transfer, based on {IsochronousTransfer#num_packets}.
    def packet_lengths=(len)
      ptr = @ptr + Call::Transfer.size
      num_packets.times do
        ptr.write_uint(len)
        ptr += Call::IsoPacketDescriptor.size
      end
    end

    # The actual_length field of the transfer is meaningless and should not
    # be examined; instead you must refer to the actual_length field of
    # each individual packet.
    private :actual_length, :actual_buffer
  end
end
