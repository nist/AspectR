require 'rbconfig'
require 'find'
require 'ftools'

include Config

$version = CONFIG["MAJOR"]+"."+CONFIG["MINOR"]
$libdir = File.join(CONFIG["libdir"], "ruby", $version)

$bindir =  CONFIG["bindir"]
$sitedir = CONFIG["sitedir"]

installdir = "" # Use top-level! Is this good?

# Install the lib files
dest = File.join($sitedir, installdir)
File::makedirs(dest)
File::chmod(0755, dest, true)
$stderr.puts "Installing library files"
libfiles = Dir["lib/*.rb"].collect {|s| s[4..-1]}
dir = Dir.open("lib")
dir.each do |file|
  next if file[0] == ?. or file.split(".").last != "rb"
  File.open(File.join("lib", file), "r") do |ip|
    File.open(File.join(dest, file), "w") do |op|
      op.write ip.read
    end
  end
end


    
