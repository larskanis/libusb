#!/usr/bin/env ruby

# Extend the search path for Windows binary gem, depending of the current ruby version
major_minor = RUBY_VERSION[ /^(\d+\.\d+)/ ] or
  raise "Oops, can't extract the major/minor version from #{RUBY_VERSION.dump}"
$: << File.join(File.dirname(__FILE__), major_minor)

require 'rubygems'
require 'ribusb_ext'
