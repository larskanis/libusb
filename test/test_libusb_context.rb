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

class TestLibusbContext < Minitest::Test
  def setup
    @c = LIBUSB::Context.new
  end

  def teardown
    @c.exit if @c
  end

  def test_set_option
    @c.set_option LIBUSB::OPTION_LOG_LEVEL, LIBUSB::LOG_LEVEL_NONE
    @c.set_option LIBUSB::OPTION_LOG_LEVEL, LIBUSB::LOG_LEVEL_ERROR
    @c.set_option LIBUSB::OPTION_LOG_LEVEL, LIBUSB::LOG_LEVEL_WARNING
    @c.set_option LIBUSB::OPTION_LOG_LEVEL, LIBUSB::LOG_LEVEL_INFO
    @c.set_option LIBUSB::OPTION_LOG_LEVEL, LIBUSB::LOG_LEVEL_DEBUG
    @c.set_option :OPTION_LOG_LEVEL, :LOG_LEVEL_NONE
  end

  def test_set_debug
    @c.debug = 4
    @c.debug = 0
  end
end
