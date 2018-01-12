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

class TestLibusbStructs < Minitest::Test
  def test_struct_Timeval
    s = LIBUSB::Call::Timeval.new
    assert_equal 0, s.in_ms
    s.in_ms = 12345678
    assert_equal 12345, s[:tv_sec]
    assert_equal 678000, s[:tv_usec]
    assert_equal 12345678, s.in_ms

    s.in_s = 1234.5678
    assert_equal 1234, s[:tv_sec]
    assert_equal 567800, s[:tv_usec]
    assert_equal 1234.5678, s.in_s
  end

  def test_struct_CompletionFlag
    s = LIBUSB::Context::CompletionFlag.new
    assert_equal 0, s[:completed]
    assert_equal false, s.completed?
    s.completed = true
    assert_equal 1, s[:completed]
    assert_equal true, s.completed?
    s.completed = false
    assert_equal false, s.completed?
    assert_equal 0, s[:completed]
  end

  def test_Transfer_buffer
    t = LIBUSB::InterruptTransfer.new allow_device_memory: true
    assert_equal :TRANSFER_COMPLETED, t.status
    assert_equal true, t.allow_device_memory
    assert_nil t.memory_type

    t.alloc_buffer(10)
    assert_equal :user_space, t.memory_type, "no device assigned -> should use memory from user space"

    t.free_buffer
    assert_nil t.memory_type
  end

  def test_Transfer_new
    assert_raises(NoMethodError){ LIBUSB::Transfer.new }
    LIBUSB::BulkStreamTransfer.new
    LIBUSB::BulkTransfer.new
    LIBUSB::ControlTransfer.new
    LIBUSB::InterruptTransfer.new
    LIBUSB::IsochronousTransfer.new(0)
  end

  def test_ControlTransfer_attributes
    t = LIBUSB::ControlTransfer.new
    t.timeout = 123
    assert_equal 123, t.timeout
    t.allow_device_memory = true
    assert_equal true, t.allow_device_memory
    assert_nil t.dev_handle
  end

  def test_ControlTransfer_new_args
    t = LIBUSB::ControlTransfer.new allow_device_memory: false, timeout: 444
    assert_equal false, t.allow_device_memory
    assert_equal 444, t.timeout
  end

  def test_Transfer_no_dev_handle
    t = LIBUSB::ControlTransfer.new
    assert_raises(ArgumentError){ t.submit_and_wait }
  end
end
