# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'hoe'
require 'pathname'
require 'uri'

# Cross-compilation constants
COMPILE_HOME               = Pathname( "./tmp" ).expand_path
STATIC_SOURCESDIR          = COMPILE_HOME + 'sources'
STATIC_BUILDDIR            = COMPILE_HOME + 'builds'

# Fetch tarball from sourceforge
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '1.0.8'
# LIBUSB_SOURCE_URI         = URI( "http://downloads.sourceforge.net/project/libusb/libusb-1.0/libusb-#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + File.basename( LIBUSB_SOURCE_URI.path )

# Fetch tarball from git repo
# LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '295c9d1'
# LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
# LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-#{LIBUSB_VERSION}.tar.bz2"

# Fetch tarball from Pete Batard's git repo
LIBUSB_VERSION            = ENV['LIBUSB_VERSION'] || '098b40d'
LIBUSB_SOURCE_URI         = URI( "http://git.libusb.org/?p=libusb-pbatard.git;a=snapshot;h=#{LIBUSB_VERSION};sf=tbz2" )
LIBUSB_TARBALL            = STATIC_SOURCESDIR + "libusb-pbatard-#{LIBUSB_VERSION}.tar.bz2"

# Static libusb build vars
STATIC_LIBUSB_BUILDDIR    = STATIC_BUILDDIR + LIBUSB_TARBALL.basename(".tar.bz2")
LIBUSB_CONFIGURE          = STATIC_LIBUSB_BUILDDIR + 'configure'
LIBUSB_MAKEFILE           = STATIC_LIBUSB_BUILDDIR + 'Makefile'
LIBUSB_DLL                  = STATIC_LIBUSB_BUILDDIR + 'libusb/.libs/libusb-1.0.dll'


hoe = Hoe.spec 'libusb' do
  developer('Lars Kanis', 'kanis@comcard.de')

  extra_deps << ['ffi', '>= 1.0']

  self.readme_file = 'README.rdoc'
  spec_extras[:rdoc_options] = ['--main', readme_file, "--charset=UTF-8"]
  self.extra_rdoc_files << self.readme_file
  self.rubyforge_name = 'libusb'
  rdoc_locations << 'larskanis@rubyforge.org:/var/www/gforge-projects/libusb/libusb'

  # clean intermediate files and folders
  self.clean_globs << STATIC_BUILDDIR.to_s
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
task LIBUSB_DLL => [ LIBUSB_MAKEFILE ] do |t|
  Dir.chdir( STATIC_LIBUSB_BUILDDIR ) do
    sh 'make'
  end
end

# copy binary from temporary location to final lib
# tmp/extension_name/extension_name.{so,bundle} => lib/
task "copy:libusb_dll" => ['lib', LIBUSB_DLL] do
  install LIBUSB_DLL, "lib/#{File.basename(LIBUSB_DLL)}"
end

desc "compile static libusb libraries"
task :libusb_dll => [ "copy:libusb_dll" ]

desc 'Cross compile libusb for win32'
task :cross => [ :mingw32, :libusb_dll ] do |t|
  spec = hoe.spec.dup
  spec.instance_variable_set(:"@cache_file", nil) if spec.respond_to?(:cache_file)
  spec.platform = Gem::Platform.new('i386-mingw32')
  spec.files << "lib/#{File.basename(LIBUSB_DLL)}"

  # Generate a package for this gem
  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end
end

task :mingw32 do
  # Use Rake::ExtensionCompiler helpers to find the proper host
  unless Rake::ExtensionCompiler.mingw_host then
    warn "You need to install mingw32 cross compile functionality to be able to continue."
    warn "Please refer to your distribution/package manager documentation about installation."
    fail
  end
end

# vim: syntax=ruby
