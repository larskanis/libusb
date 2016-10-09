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

class TestLibusbHotplug < Minitest::Test
  include LIBUSB

  attr_reader :ctx

  def setup
    @ctx = Context.new
  end

  def teardown
    @ctx.exit
  end

  def test_enumerate
    devs = []
    ctx.on_hotplug_event flags: HOTPLUG_ENUMERATE do |dev, event|
      devs << dev
      assert_equal :HOTPLUG_EVENT_DEVICE_ARRIVED, event
      :repeat
    end
    # Not really necessary, but just to be sure that the callback was called:
    ctx.handle_events 0

    assert_equal ctx.devices.sort, devs.sort
  end

  def test_enumerate_with_left
    devs = []
    ctx.on_hotplug_event flags: HOTPLUG_ENUMERATE, events: HOTPLUG_EVENT_DEVICE_LEFT do |dev, event|
      devs << dev
      assert_equal :HOTPLUG_EVENT_DEVICE_ARRIVED, event
      :repeat
    end
    # Not really necessary, but just to be sure that the callback was called:
    ctx.handle_events 0

    assert_equal [], devs.sort, "Enumerate should not send any LEFT events"
  end

  def test_deregister
    handle1 = ctx.on_hotplug_event{ assert false, "Callback should not be called" }
    handle2 = ctx.on_hotplug_event{ assert false, "Callback should not be called" }
    handle1.deregister
    handle2.deregister
    ctx.handle_events 0
  end

  def test_wrong_yieldreturn
    ex = assert_raises(ArgumentError) do
      ctx.on_hotplug_event flags: :HOTPLUG_ENUMERATE do |dev, event|
      end
    end

    assert_match(/:finish.*:repeat/, ex.to_s, "Should give a useful hint")
  end

  def test_context
    handle = ctx.on_hotplug_event do |dev, event|
    end
    assert_equal ctx, handle.context, "The callback handle should have it's context"
  end

  def test_real_device_plugging_and_yieldreturn_and_gc_and_deregister
    # This callback should be triggered once
    devs = []
    ctx.on_hotplug_event do |dev, event|
      devs << [dev, event]
      :finish
    end

    # This callback should be triggered twice
    devs2 = []
    ctx.on_hotplug_event do |dev, event|
      devs2 << [dev, event]
      puts format("  %p: %p", event, dev)
      :repeat
    end

    # This callback should never be triggered
    handle = ctx.on_hotplug_event{ assert false, "Deregistered callback should never be called" }

    # GC shouldn't free any relevant callbacks or blocks
    GC.start

    print "\nPlease add and remove an USB device (2*5 sec): "
    handle.deregister
    ctx.handle_events 0
    ctx.handle_events 5000
    ctx.handle_events 5000

    skip "no hotplug action taken" if devs.empty? && devs2.empty?
    assert_equal 1, devs.length, "Should be deregistered after the first event"
    assert_equal 2, devs2.length, "Should have received two events"
    assert_operator devs2.map(&:last), :include?, :HOTPLUG_EVENT_DEVICE_ARRIVED, "Should have received ARRIVED"
    assert_operator devs2.map(&:last), :include?, :HOTPLUG_EVENT_DEVICE_LEFT, "Should have received LEFT"
  end
end
