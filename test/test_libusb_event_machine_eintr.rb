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

require "minitest/autorun"
require "libusb"
require "libusb/eventmachine"
require "eventmachine"

# LIBUSB_ERROR_INTERRUPTED means poll() was interrupted by a signal and no
# events were handled. It is transient and retryable, but Context#handle_events
# raises on it like any other negative return, and the EventMachine integration
# used to call handle_events unrescued -- so a signal arriving at the wrong
# moment unwound out of EventMachine.run and killed the reactor.
#
# These tests need no USB device: they drive the registered callback directly.
class TestLibusbEventMachineEintr < Minitest::Test
  include LIBUSB

  def setup
    @context = Context.new
    skip "libusb pollfd API not available on this platform" unless @context.pollfds&.any?
  end

  # The callback the pollfd handler invokes must swallow ERROR_INTERRUPTED and
  # leave the reactor running.
  def test_pollfd_callback_survives_eintr
    interrupts = 0
    @context.define_singleton_method(:handle_events) do |*|
      interrupts += 1
      raise LIBUSB::ERROR_INTERRUPTED
    end

    assert dispatch_pollfd_events, "reactor must stay up after ERROR_INTERRUPTED"
    assert_operator interrupts, :>=, 1, "handle_events should have been called"
  end

  # Only ERROR_INTERRUPTED is transient. Every other libusb error must still
  # propagate, so a real fault is not silently swallowed.
  def test_pollfd_callback_still_raises_other_errors
    @context.define_singleton_method(:handle_events) do |*|
      raise LIBUSB::ERROR_NO_DEVICE
    end

    assert_raises(LIBUSB::ERROR_NO_DEVICE) { dispatch_pollfd_events }
  end

  private

  # Run the reactor, register libusb's pollfds with it and invoke the resulting
  # callbacks exactly as EMPollfdHandler#notify_readable does. Returns whether
  # the reactor was still running once they had been dispatched.
  def dispatch_pollfd_events
    reactor_alive = false

    EventMachine.run do
      @context.eventmachine_register

      begin
        @context.instance_variable_get(:@eventmachine_attached_fds).each_value(&:need_handle_events)
        reactor_alive = EventMachine.reactor_running?
      ensure
        @context.eventmachine_unregister
        EventMachine.stop
      end
    end

    reactor_alive
  end
end
