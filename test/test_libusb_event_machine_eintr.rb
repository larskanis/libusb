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
  end

  # The callback the pollfd handler invokes must swallow ERROR_INTERRUPTED and
  # leave the reactor running.
  def test_pollfd_callback_survives_eintr
    interrupts = 0
    @context.define_singleton_method(:handle_events) do |*|
      interrupts += 1
      raise LIBUSB::ERROR_INTERRUPTED
    end

    survived = false
    EventMachine.run do
      @context.eventmachine_register
      conns = @context.instance_variable_get(:@eventmachine_attached_fds)

      if conns.nil? || conns.empty?
        @context.eventmachine_unregister
        EventMachine.stop
        skip "no libusb pollfds on this platform"
      end

      # This is exactly what EMPollfdHandler#notify_readable does.
      conns.each_value(&:need_handle_events)

      survived = EventMachine.reactor_running?
      @context.eventmachine_unregister
      EventMachine.stop
    end

    assert_operator interrupts, :>=, 1, "handle_events should have been called"
    assert survived, "reactor must stay up after ERROR_INTERRUPTED"
  end

  # Only ERROR_INTERRUPTED is transient. Every other libusb error must still
  # propagate, so a real fault is not silently swallowed.
  def test_pollfd_callback_still_raises_other_errors
    @context.define_singleton_method(:handle_events) do |*|
      raise LIBUSB::ERROR_NO_DEVICE
    end

    assert_raises(LIBUSB::ERROR_NO_DEVICE) do
      EventMachine.run do
        @context.eventmachine_register
        conns = @context.instance_variable_get(:@eventmachine_attached_fds)

        if conns.nil? || conns.empty?
          @context.eventmachine_unregister
          EventMachine.stop
          skip "no libusb pollfds on this platform"
        end

        begin
          conns.each_value(&:need_handle_events)
        ensure
          EventMachine.stop
        end
      end
    end
  end
end
