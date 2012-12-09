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

require "test/unit"
require "libusb"

class TestLibusbStructs < Test::Unit::TestCase
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
end
