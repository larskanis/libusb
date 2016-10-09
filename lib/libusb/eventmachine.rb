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

require 'libusb'
require 'eventmachine'

module LIBUSB
class Context
  # Register libusb's file descriptors and timeouts to EventMachine.
  #
  # @example
  #   require 'libusb/eventmachine'
  #   context = LIBUSB::Context.new
  #   EventMachine.run do
  #     context.eventmachine_register
  #   end
  #
  # @see
  #   DevHandle#eventmachine_bulk_transfer
  #   DevHandle#eventmachine_control_transfer
  #   DevHandle#eventmachine_interrupt_transfer
  def eventmachine_register
    @eventmachine_attached_fds = {}
    @eventmachine_timer = nil

    pollfds = self.pollfds
    if pollfds
      pollfds.each do |pollfd|
        eventmachine_add_pollfd(pollfd)
      end

      self.on_pollfd_added do |pollfd|
        eventmachine_add_pollfd(pollfd)
      end

      self.on_pollfd_removed do |pollfd|
        eventmachine_rm_pollfd(pollfd)
      end
    else
      # Libusb pollfd API is not available on this platform.
      # Use simple polling timer, instead:
      EventMachine.add_periodic_timer(0.01) do
        @eventmachine_timer = self.handle_events 0
      end
    end
  end

  def eventmachine_unregister
    @eventmachine_timer.cancel if @eventmachine_timer
    @eventmachine_attached_fds.each do |fd, watcher|
      watcher.detach
    end
  end

  class EMPollfdHandler < EventMachine::Connection
    def initialize
      @callbacks = []
      super
    end

    def on_need_handle_events(&block)
      @callbacks << block
    end

    def need_handle_events
      @callbacks.each do |cb|
        cb.call
      end
    end
    alias notify_readable need_handle_events
    alias notify_writable need_handle_events
  end

  private
  def eventmachine_add_pollfd(pollfd)
    conn = EventMachine.watch(pollfd.io, EMPollfdHandler)
    conn.notify_readable = pollfd.pollin?
    conn.notify_writable = pollfd.pollout?
    cb = proc do
      if @eventmachine_timer
        @eventmachine_timer.cancel
        @eventmachine_timer = nil
      end

      self.handle_events 0
      timeout = self.next_timeout
#         puts "libusb new timeout: #{timeout.inspect}"
      if timeout
        @eventmachine_timer = EventMachine.add_timer(timeout, &cb)
      end
    end
    conn.on_need_handle_events(&cb)

    @eventmachine_attached_fds[pollfd.fd] = conn
#       puts "libusb pollfd added: #{pollfd.inspect}"
  end

  def eventmachine_rm_pollfd(pollfd)
    @eventmachine_attached_fds[pollfd.fd].detach
#       puts "libusb pollfd removed: #{pollfd.inspect}"
  end
end

class DevHandle
  class EMTransfer
    include EM::Deferrable

    def initialize(opts, dev_handle, transfer_method)
      dev_handle.send(transfer_method, opts) do |res|
        EM.next_tick do
          if res.kind_of?(LIBUSB::Error)
            fail res
          else
            succeed res
          end
        end
      end
    end
  end

  # Execute an eventmachine driven USB interrupt transfer.
  #
  # @see Context#eventmachine_register
  #   DevHandle#interrupt_transfer
  def eventmachine_interrupt_transfer(opts={})
    eventmachine_transfer(opts, :interrupt_transfer)
  end

  # Execute an eventmachine driven USB bulk transfer.
  #
  # @example
  #   tr = devh.eventmachine_bulk_transfer( endpoint: 0x02, dataOut: "data" )
  #   tr.callback do |data|
  #     puts "sent: #{data.inspect}"
  #   end
  #   tr.errback do |ex|
  #     puts "send-err: #{ex}"
  #   end
  #
  # @see Context#eventmachine_register
  #   DevHandle#bulk_transfer
  def eventmachine_bulk_transfer(opts={})
    eventmachine_transfer(opts, :bulk_transfer)
  end

  # Execute an eventmachine driven USB control transfer.
  #
  # @example
  #   tr = devh.eventmachine_control_transfer(
  #     bmRequestType: ENDPOINT_IN|REQUEST_TYPE_CLASS|RECIPIENT_INTERFACE,
  #     bRequest: 0x01,
  #     wValue: 0, wIndex: 0, dataIn: 1 )
  #   tr.callback do |data|
  #     puts "recved: #{data.inspect}"
  #   end
  #   tr.errback do |ex|
  #     puts "recv-err: #{ex}"
  #   end
  #
  # @see Context#eventmachine_register
  #   DevHandle#control_transfer
  def eventmachine_control_transfer(opts={})
    eventmachine_transfer(opts, :control_transfer)
  end

  private
  def eventmachine_transfer(opts, method)
    EMTransfer.new opts, self, method
  end
end
end
