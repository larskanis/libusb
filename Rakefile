# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'hoe'
require 'rake/extensiontask'

hoe = Hoe.spec 'ribusb' do
  developer('András G. Major', 'andras.g.major@gmail.com')
  developer('Lars Kanis', 'kanis@comcard.de')

  self.readme_file = 'README.rdoc'
  spec_extras[:extensions] = 'ext/extconf.rb'
  spec_extras[:rdoc_options] = ['--main', readme_file, "--charset=UTF-8"]
  self.extra_rdoc_files << self.readme_file << 'ext/ribusb.c'
  self.rubyforge_name = 'ribusb'
  rdoc_locations << 'larskanis@rubyforge.org:/var/www/gforge-projects/ribusb/ribusb'
end

ENV['RUBY_CC_VERSION'] ||= '1.8.6:1.9.2'

# Cross-compilation constants
GEMSPEC = hoe.spec
COMPILE_HOME               = Pathname( "~/.rake-compiler" ).expand_path
STATIC_SOURCESDIR          = COMPILE_HOME + 'sources'
STATIC_BUILDDIR            = COMPILE_HOME + 'builds'

# Fetch tarball from sourceforge
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '1.0.8'
# LIBUSB_SOURCE_URI         = URI( "http://downloads.sourceforge.net/project/libusb/libusb-1.0/libusb-#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + File.basename( LIBUSB_SOURCE_URI.path )

# Fetch tarball from git repo
LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '295c9d1'
LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-#{LIBUSB_VERSION}.tar.bz2"

# Fetch tarball from Pete Batard's git repo
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '098b40d'
# LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb-pbatard.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-pbatard-#{LIBUSB_VERSION}.tar.bz2"

# Static libusb build vars
STATIC_LIBUSB_BUILDDIR    = STATIC_BUILDDIR + LIBUSB_TARBALL.basename(".tar.bz2")
LIBUSB_CONFIGURE          = STATIC_LIBUSB_BUILDDIR + 'configure'
LIBUSB_MAKEFILE           = STATIC_LIBUSB_BUILDDIR + 'Makefile'
LIBUSB_A                  = STATIC_LIBUSB_BUILDDIR + 'libusb.a'

# clean intermediate files and folders
CLEAN.include( STATIC_BUILDDIR.to_s )

Rake::ExtensionTask.new('ribusb_ext', hoe.spec) do |ext|
  ext.ext_dir = 'ext'
  ext.cross_compile = true                # enable cross compilation (requires cross compile toolchain)
  ext.cross_platform = ['i386-mswin32', 'i386-mingw32']     # forces the Windows platform instead of the default one

  # configure options only for cross compile
  ext.cross_config_options += [
    "--with-libusb-lib=#{STATIC_LIBUSB_BUILDDIR}/libusb/.libs",
    "--with-libusb-include=#{STATIC_LIBUSB_BUILDDIR}/libusb",
    "--enable-win32-static-build",
  ]
end


require 'rake/extensiontask'
require 'rake/extensioncompiler'

#####################################################################
### C R O S S - C O M P I L A T I O N - T A S K S
#####################################################################


directory STATIC_SOURCESDIR.to_s

#
# Static libusb build tasks
#
directory STATIC_LIBUSB_BUILDDIR.to_s

# libusb source file should be stored there
file LIBUSB_TARBALL => STATIC_SOURCESDIR do |t|
  # download the source file using wget or curl
  chdir File.dirname(t.name) do
    url = LIBUSB_SOURCE_URI
    sh "wget '#{url}' -O #{LIBUSB_TARBALL}"
  end
end

# Extract the libusb builds
file STATIC_LIBUSB_BUILDDIR => LIBUSB_TARBALL do |t|
  sh 'tar', '-xjf', LIBUSB_TARBALL.to_s, '-C', STATIC_LIBUSB_BUILDDIR.parent.to_s
  LIBUSB_MAKEFILE.unlink if LIBUSB_MAKEFILE.exist?
end

file LIBUSB_CONFIGURE => STATIC_LIBUSB_BUILDDIR do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    sh "sh autogen.sh && make distclean"
  end
end

# generate the makefile in a clean build location
file LIBUSB_MAKEFILE => LIBUSB_CONFIGURE do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    options = [
      '--target=i386-mingw32',
      "--host=#{Rake::ExtensionCompiler.mingw_host}",
    ]
    build_host = `sh config.guess`.chomp
    options << "--build=#{build_host}" unless build_host.to_s.empty?

    configure_path = STATIC_LIBUSB_BUILDDIR + 'configure'
    cmd = [ configure_path.to_s, *options ]
    sh *cmd
  end
end

# make libusb-1.0.a
task LIBUSB_A => [ LIBUSB_MAKEFILE ] do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    sh 'make'
  end
end

desc "compile static libusb libraries"
task :static_libusb => [ LIBUSB_A ]

desc 'cross compile pg for win32'
task :cross => [ :mingw32, :static_libusb ]

task :mingw32 do
  # Use Rake::ExtensionCompiler helpers to find the proper host
  unless Rake::ExtensionCompiler.mingw_host then
    warn "You need to install mingw32 cross compile functionality to be able to continue."
    warn "Please refer to your distribution/package manager documentation about installation."
    fail
  end
end

# vim: syntax=ruby
