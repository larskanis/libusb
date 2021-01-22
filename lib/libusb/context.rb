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
    class Pollfd
      include Comparable

      def initialize(fd, events=0)
        @fd, @events = fd, events
      end

      def <=>(other)
        @fd <=> other.fd
      end

      # @return [IO]  IO object bound to the file descriptor.
      def io
        rio = IO.new @fd
        # autoclose is available in Ruby-1.9+ only
        rio.autoclose = false if rio.respond_to?( :autoclose= )
        rio
      end

      # @return [Integer]  Numeric file descriptor
      attr_reader :fd

      # @return [Integer]  Event flags to poll for
      attr_reader :events

      # @return [Boolean] True if the file descriptor has to be observed for incoming/readable data
      def pollin?
        @events & POLLIN != 0
      end

      # @return [Boolean] True if the file descriptor has to be observed for outgoing/writeable data
      def pollout?
        @events & POLLOUT != 0
      end

      def inspect
        "\#<#{self.class} fd:#{@fd}#{' POLLIN' if pollin?}#{' POLLOUT' if pollout?}>"
      end
    end

    class CompletionFlag < FFI::Struct
      layout :completed,  :int

      def completed?
        self[:completed] != 0
      end

      def completed=(flag)
        self[:completed] = flag ? 1 : 0
      end
    end

    class HotplugCallback < FFI::Struct
      layout :handle,  :int

      attr_reader :context

      # @private
      def initialize(context, ctx, callbacks)
        super()
        @context = context
        @ctx = ctx
        @callbacks = callbacks
      end

      # Deregisters the hotplug callback.
      #
      # Deregister a callback from a {Context}. This function is safe to call from within
      # a hotplug callback.
      #
      # Since libusb version 1.0.16.
      def deregister
        Call.libusb_hotplug_deregister_callback(@ctx, self[:handle])
        @callbacks.delete(self[:handle])
      end
    end


    # Initialize libusb context.
    def initialize
      m = FFI::MemoryPointer.new :pointer
      res = Call.libusb_init(m)
      LIBUSB.raise_error res, "in libusb_init" if res!=0
      @ctx = m.read_pointer
      @on_pollfd_added = nil
      @on_pollfd_removed = nil
      @hotplug_callbacks = {}
    end

    # Deinitialize libusb.
    #
    # Should be called after closing all open devices and before your application terminates.
    def exit
      Call.libusb_exit(@ctx)
    end

    # @deprecated Use {Context#set_option} instead using the +:OPTION_LOG_LEVEL+ option.
    def debug=(level)
      Call.libusb_set_debug(@ctx, level)
    end

    private def expect_option_args(exp, is)
      raise ArgumentError, "wrong number of arguments (given #{is+1}, expected #{exp+1})" if is != exp
    end

    # Set a libusb option from the {Call::Options option list}.
    #
    # @param [Symbol, Fixnum] option
    # @param args  Zero or more arguments depending on +option+
    def set_option(option, *args)
      if Call.respond_to?(:libusb_set_option)
        # Available since libusb-1.0.22

        ffi_args = case option
          when :OPTION_LOG_LEVEL, LIBUSB::OPTION_LOG_LEVEL
            expect_option_args(1, args.length)
            [:libusb_log_level, args[0]]
          when :OPTION_USE_USBDK, LIBUSB::OPTION_USE_USBDK
            expect_option_args(0, args.length)
            []
          else
            raise ArgumentError, "unknown option #{option.inspect}"
        end

        res = Call.libusb_set_option(@ctx, option, *ffi_args)
        LIBUSB.raise_error res, "in libusb_set_option" if res<0

      else
        # Fallback to deprecated function, if the gem is linked to an older libusb.

        raise ArgumentError, "unknown option #{option.inspect}" unless [:OPTION_LOG_LEVEL, LIBUSB::OPTION_LOG_LEVEL].include?(option)
        Call.libusb_set_debug(@ctx, *args)
      end
    end

    def device_list
      pppDevs = FFI::MemoryPointer.new :pointer
      size = Call.libusb_get_device_list(@ctx, pppDevs)
      LIBUSB.raise_error size, "in libusb_get_device_list" if size<0
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
    #
    # If a zero timeout is passed, this function will handle any already-pending
    # events and then immediately return in non-blocking style.
    #
    # If a non-zero timeout is passed and no events are currently pending, this
    # method will block waiting for events to handle up until the specified timeout.
    # If an event arrives or a signal is raised, this method will return early.
    #
    # If the parameter completion_flag is used, then after obtaining the event
    # handling lock this function will return immediately if the flag is set to completed.
    # This allows for race free waiting for the completion of a specific transfer.
    # See source of {Transfer#submit_and_wait} for a use case of completion_flag.
    #
    # @param [Integer, nil] timeout  the maximum time (in millseconds) to block waiting for
    #                                events, or 0 for non-blocking mode
    # @param [Context::CompletionFlag, nil] completion_flag  CompletionFlag to check
    #
    # @see interrupt_event_handler
    def handle_events(timeout=nil, completion_flag=nil)
      if completion_flag && !completion_flag.is_a?(Context::CompletionFlag)
        raise ArgumentError, "completion_flag is not a CompletionFlag"
      end
      if timeout
        timeval = Call::Timeval.new
        timeval.in_ms = timeout
        res = if Call.respond_to?(:libusb_handle_events_timeout_completed)
          Call.libusb_handle_events_timeout_completed(@ctx, timeval, completion_flag)
        else
          Call.libusb_handle_events_timeout(@ctx, timeval)
        end
      else
        res = if Call.respond_to?(:libusb_handle_events_completed)
          Call.libusb_handle_events_completed(@ctx, completion_flag )
        else
          Call.libusb_handle_events(@ctx)
        end
      end
      LIBUSB.raise_error res, "in libusb_handle_events" if res<0
    end

    if Call.respond_to?(:libusb_interrupt_event_handler)
      # Interrupt any active thread that is handling events.
      #
      # This is mainly useful for interrupting a dedicated event handling thread when an application wishes to call {Context#exit}.
      #
      # Available since libusb-1.0.21.
      #
      # @see handle_events
      def interrupt_event_handler
        Call.libusb_interrupt_event_handler(@ctx)
      end
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
    #   context.device idVendor: 0x0ab1, idProduct: [0x0003, 0x0004]
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


    # Retrieve a list of file descriptors that should be polled by your main
    # loop as libusb event sources.
    #
    # As file descriptors are a Unix-specific concept, this function is not
    # available on Windows and will always return +nil+.
    #
    # @return [Array<Pollfd>]  list of Pollfd objects,
    #   +nil+ on error,
    #   +nil+ on platforms where the functionality is not available
    def pollfds
      ppPollfds = Call.libusb_get_pollfds(@ctx)
      return nil if ppPollfds.null?
      offs = 0
      pollfds = []
      while !(pPollfd=ppPollfds.get_pointer(offs)).null?
        pollfd = Call::Pollfd.new pPollfd
        pollfds << Pollfd.new(pollfd[:fd], pollfd[:events])
        offs += FFI.type_size :pointer
      end
      if Call.respond_to?(:libusb_free_pollfds)
        Call.libusb_free_pollfds(ppPollfds)
      else
        Stdio.free(ppPollfds)
      end
      pollfds
    end

    # Determine the next internal timeout that libusb needs to handle.
    #
    # You only need to use this function if you are calling poll() or select() or
    # similar on libusb's file descriptors yourself - you do not need to use it if
    # you are calling {#handle_events} directly.
    #
    # You should call this function in your main loop in order to determine how long
    # to wait for select() or poll() to return results. libusb needs to be called
    # into at this timeout, so you should use it as an upper bound on your select() or
    # poll() call.
    #
    # When the timeout has expired, call into {#handle_events} (perhaps
    # in non-blocking mode) so that libusb can handle the timeout.
    #
    # This function may return zero. If this is the
    # case, it indicates that libusb has a timeout that has already expired so you
    # should call {#handle_events} immediately. A return code
    # of +nil+ indicates that there are no pending timeouts.
    #
    # On some platforms, this function will always returns +nil+ (no pending timeouts).
    # See libusb's notes on time-based events.
    #
    # @return [Float, nil]  the timeout in seconds
    def next_timeout
      timeval = Call::Timeval.new
      res = Call.libusb_get_next_timeout @ctx, timeval
      LIBUSB.raise_error res, "in libusb_get_next_timeout" if res<0
      res == 1 ? timeval.in_s : nil
    end

    # Register a notification block for file descriptor additions.
    #
    # This block will be invoked for every new file descriptor that
    # libusb uses as an event source.
    #
    # Note that file descriptors may have been added even before you register these
    # notifiers (e.g. at {Context#initialize} time).
    #
    # @yieldparam [Pollfd] pollfd  The added file descriptor is yielded to the block
    def on_pollfd_added &block
      @on_pollfd_added = proc do |fd, events, _|
        pollfd = Pollfd.new fd, events
        block.call pollfd
      end
      Call.libusb_set_pollfd_notifiers @ctx, @on_pollfd_added, @on_pollfd_removed, nil
    end

    # Register a notification block for file descriptor removals.
    #
    # This block will be invoked for every removed file descriptor that
    # libusb uses as an event source.
    #
    # Note that the removal notifier may be called during {Context#exit}
    # (e.g. when it is closing file descriptors that were opened and added to the poll
    # set at {Context#initialize} time). If you don't want this, overwrite the notifier
    # immediately before calling {Context#exit}.
    #
    # @yieldparam [Pollfd] pollfd  The removed file descriptor is yielded to the block
    def on_pollfd_removed &block
      @on_pollfd_removed = proc do |fd, _|
        pollfd = Pollfd.new fd
        block.call pollfd
      end
      Call.libusb_set_pollfd_notifiers @ctx, @on_pollfd_added, @on_pollfd_removed, nil
    end

    # Register a hotplug event notification.
    #
    # Register a callback with the {LIBUSB::Context}. The callback will fire
    # when a matching event occurs on a matching device. The callback is armed
    # until either it is deregistered with {HotplugCallback#deregister} or the
    # supplied block returns +:finish+ to indicate it is finished processing events.
    #
    # If the flag {Call::HotplugFlags HOTPLUG_ENUMERATE} is passed the callback will be
    # called with a {Call::HotplugEvents :HOTPLUG_EVENT_DEVICE_ARRIVED} for all devices
    # already plugged into the machine. Note that libusb modifies its internal
    # device list from a separate thread, while calling hotplug callbacks from
    # {#handle_events}, so it is possible for a device to already be present
    # on, or removed from, its internal device list, while the hotplug callbacks
    # still need to be dispatched. This means that when using
    # {Call::HotplugFlags HOTPLUG_ENUMERATE}, your callback may be called twice for the arrival
    # of the same device, once from {#on_hotplug_event} and once
    # from {#handle_events}; and/or your callback may be called for the
    # removal of a device for which an arrived call was never made.
    #
    # Since libusb version 1.0.16.
    #
    # @param [Hash] args
    # @option args [Fixnum,Symbol] :events  bitwise or of events that will trigger this callback.
    #   Default is +LIBUSB::HOTPLUG_EVENT_DEVICE_ARRIVED|LIBUSB::HOTPLUG_EVENT_DEVICE_LEFT+ .
    #   See {Call::HotplugEvents HotplugEvents}
    # @option args [Fixnum,Symbol] :flags hotplug callback flags. Default is 0. See {Call::HotplugFlags HotplugFlags}
    # @option args [Fixnum] :vendor_id the vendor id to match. Default is {HOTPLUG_MATCH_ANY}.
    # @option args [Fixnum] :product_id the product id to match. Default is {HOTPLUG_MATCH_ANY}.
    # @option args [Fixnum] :dev_class the device class to match. Default is {HOTPLUG_MATCH_ANY}.
    # @return [HotplugCallback]  The handle to the registered callback.
    #
    # @yieldparam [Device] device  the attached or removed {Device} is yielded to the block
    # @yieldparam [Symbol] event  a {Call::HotplugEvents HotplugEvents} symbol
    # @yieldreturn [Symbol] +:finish+ to deregister the callback, +:repeat+ to receive additional events
    # @raise [ArgumentError, LIBUSB::Error] in case of failure
    def on_hotplug_event(events: HOTPLUG_EVENT_DEVICE_ARRIVED | HOTPLUG_EVENT_DEVICE_LEFT,
                         flags: 0,
                         vendor_id: HOTPLUG_MATCH_ANY,
                         product_id: HOTPLUG_MATCH_ANY,
                         dev_class: HOTPLUG_MATCH_ANY,
                         &block)

      handle = HotplugCallback.new self, @ctx, @hotplug_callbacks

      block2 = proc do |ctx, pDevice, event, _user_data|
        raise "internal error: unexpected context" unless @ctx==ctx
        dev = Device.new @ctx, pDevice

        blres = block.call(dev, event)

        case blres
        when :finish
          1
        when :repeat
          0
        else
          raise ArgumentError, "hotplug event handler must return :finish or :repeat"
        end
      end

      res = Call.libusb_hotplug_register_callback(@ctx,
                  events, flags,
                  vendor_id, product_id, dev_class,
                  block2, nil, handle)

      LIBUSB.raise_error res, "in libusb_hotplug_register_callback" if res<0

      # Avoid GC'ing of the block:
      @hotplug_callbacks[handle[:handle]] = block2

      return handle
    end
  end
end
