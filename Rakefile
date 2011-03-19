# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'hoe'
require 'rake/extensiontask'

hoe = Hoe.spec 'ribusb' do
  developer('András G. Major', 'andras.g.major@gmail.com')

  spec_extras[:extensions] = 'ext/extconf.rb'
  spec_extras[:rdoc_options] = ['--main', readme_file, "--charset=UTF-8"]
  self.extra_rdoc_files << 'ext/ribusb.c'
  self.rubyforge_name = 'ribusb'
end

ENV['RUBY_CC_VERSION'] ||= '1.8.6:1.9.2'

Rake::ExtensionTask.new('ribusb_ext', hoe.spec) do |ext|
  ext.ext_dir = 'ext'
  ext.cross_compile = true                # enable cross compilation (requires cross compile toolchain)
  ext.cross_platform = ['i386-mswin32', 'i386-mingw32']     # forces the Windows platform instead of the default one
end

# vim: syntax=ruby
