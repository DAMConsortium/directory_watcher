require 'directory_watcher'
require 'rspec/autorun'
require 'scanner_scenarios'
require 'utility_classes'

require 'logging'
include Logging.globally
Logging.logger.root.appenders = Logging.appenders.stderr
Logging.logger.root.level = :off
#Thread.abort_on_exception = true

module DirectoryWatcherSpecs::Helpers
  def scratch_path( *parts )
    File.join( @scratch_dir, *parts )
  end

  # NOTE : touch will only work on *nix/BSD style systems
  # Touch the file with the given timestamp
  def touch( fname, time = Time.now )
    stamp = time.strftime("%Y%m%d%H%M.%S")
    %x[ touch -m -t #{stamp} #{fname} ]
  end

  def append_to( fname, count = 1 )
    File.open( fname, "a" ) { |f| count.times { f.puts Time.now }}
  end
end

RSpec.configure do |config|
  config.before(:each) do
    @spec_dir = DirectoryWatcher.sub_path( "spec" )
    @scratch_dir = File.join(@spec_dir, "scratch")
    FileUtils.rm_rf @scratch_dir if File.directory?( @scratch_dir )
    FileUtils.mkdir @scratch_dir unless File.directory?( @scratch_dir )
  end

  config.after(:each) do
    FileUtils.rm_rf @scratch_dir if File.directory?(@scratch_dir)
  end

  config.include DirectoryWatcherSpecs::Helpers

end

RSpec::Matchers.define :be_events_like do |expected|
  match do |actual|
    type_and_name(actual) == expected
  end

  failure_message_for_should do |actual|
    "expected #{type_and_name(actual).inspect} to be events like #{expected.inspect}"
  end

  def type_and_name( actual )
    actual.map {|e| [ e.type, File.basename( e.path ) ]}
  end
end
