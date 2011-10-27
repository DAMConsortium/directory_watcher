begin
  require 'coolio'
  DirectoryWatcher::HAVE_COOLIO = true
rescue LoadError
  DirectoryWatcher::HAVE_COOLIO = false
end

if DirectoryWatcher::HAVE_COOLIO

# The CoolioScanner uses the Coolio loop to monitor changes to files in the
# watched directory. This scanner is more efficient than the pure Ruby
# scanner because it relies on the operating system kernel notifictions
# instead of a periodic polling and stat of every file in the watched
# directory (the technique used by the Scanner class).
#
class DirectoryWatcher::CoolioScanner < DirectoryWatcher::EventableScanner
  # call-seq:
  #    CoolioScanner.new( glob, interval, collection_queue )
  #
  def initialize( glob, interval, collection_queue )
    super(glob, interval, collection_queue)
  end

  def start_loop_with_attached_scan_timer
    return if @loop_thread
    @timer = ScanTimer.new( self )
    @loop_thread = Thread.new {
      @timer.attach(event_loop)
      event_loop.run
    }
  end

  def stop_loop
    if @loop_thread then
      event_loop.stop rescue nil
      @loop_thread.kill
      @loop_thread = nil
    end
  end

  #
  # Return the cool.io loop object
  #
  def event_loop
    if @loop_thread then
      @loop_thread._coolio_loop
    else
      Thread.current._coolio_loop
    end
  end

  # :stopdoc:
  #
  # Watch files using the Coolio StatWatcher.
  #
  # The coolio +on_change+ callback is converted to the appropriate +on_removed+
  # and +on_modified+ callbacks for the EventableScanner.
  class Watcher < Coolio::StatWatcher
    def self.watch(fn, scanner )
      new(fn, scanner)
    end

    def initialize( fn, scanner )
      # for file watching, we want to make sure this happens at a reasonable
      # value, so set it to 0 if the scanner.interval is > 5 seconds. This will
      # make it use the system value, and allow us to test.
      i = scanner.interval < 5 ? scanner.interval : 0
      super(fn, i)
      @scanner = scanner
      attach(scanner.event_loop)
    end

    # Cool.io uses on_change so we convert that to the appropriate
    # EventableScanner calls.
    #
    def on_change( prev_stat, current_stat )
      if File.exist?(path) then
        @scanner.on_removed( ::DirectoryWatcher::FileStat.for_removed_path(path) )
      else
        @scanner.on_modified( ::DirectoryWatcher::FileStat.new(path, current_stat.mtime, current_stat.size) )
      end
    end
  end

  # Periodically execute a Scan.
  #
  class ScanTimer< Coolio::TimerWatcher
    def initialize( scanner )
      super(scanner.interval, true)
      @scanner = scanner
    end

    def on_timer( *args )
      @scanner.on_scan
    end
  end
  # :startdoc:
end  # class DirectoryWatcher::CoolioScanner

end  # if DirectoryWatcher::HAVE_COOLIO

# EOF
