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
    ctx.on_hotplug_event :flags => HOTPLUG_ENUMERATE do |dev, event|
      devs << dev
      assert_equal :HOTPLUG_EVENT_DEVICE_ARRIVED, event
    end
    # Not really necessary, but just to be sure that the callback was called:
    ctx.handle_events 0

    assert_equal ctx.devices.sort, devs.sort
  end

  def test_deregister
    handle1 = ctx.on_hotplug_event{ assert false, "Callback should not be called" }
    handle2 = ctx.on_hotplug_event{ assert false, "Callback should not be called" }
    handle1.deregister
    handle2.deregister
  end

  def add_callback(events)
    devs = []
    handle = ctx.on_hotplug_event :events => events do |dev, event|
      devs << [dev, event]
      handle.deregister
    end
    devs
  end

  def test_gc
    adevs = add_callback HOTPLUG_EVENT_DEVICE_ARRIVED
    ldevs = add_callback HOTPLUG_EVENT_DEVICE_LEFT
    handle = ctx.on_hotplug_event{ assert false, "Deregistered callback should not be called" }

    GC.start

    print "\nPlease add or remove an USB device (5 sec): "
    handle.deregister
    ctx.handle_events 0
    ctx.handle_events 5000

    devs = adevs + ldevs
    skip if devs.empty?
    devs.each do |dev, event|
      puts format("  %p: %p", event, dev)
    end
    assert_equal 1, devs.length, "Should be deregistered after the first event"
  end
end
