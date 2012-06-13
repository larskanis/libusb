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

class TestLibusbVersion < Test::Unit::TestCase
  def setup
    @v = LIBUSB.version
  end

  def test_version_parts
    assert_operator @v.major, :>=, 0
    assert_operator @v.minor, :>=, 0
    assert_operator @v.micro, :>=, 0
    assert_operator @v.nano, :>=, 0
    assert_kind_of String, @v.rc
  end

  def test_version_string
    assert_match(/^\d+\.\d+\.\d+/, @v.to_s)
    assert_match(/^#<LIBUSB::Version \d+\.\d+\.\d+/, @v.inspect)
  end
end
