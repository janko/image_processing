module ImageProcessing
  module Vips
    # Streams an IO object into libvips.
    #
    # libvips calls the read callback from its own threads, but some IO objects
    # can only be read from the thread that created them (e.g. Down::ChunkedIO
    # resumes a Fiber, and sockets managed by a fiber scheduler rely on the
    # current thread's scheduler). So the calling thread reads the IO and hands
    # the chunks over through a bounded queue, while libvips runs in a separate
    # thread.
    class IOSource
      CHUNK_SIZE = 64 * 1024
      QUEUE_SIZE = 4

      # Calls the block in a separate thread with a Vips::Source that streams
      # the given IO object, and returns the block's result. The IO object is
      # read in the current thread.
      def self.process(io, &block)
        new(io).process(&block)
      end

      def initialize(io)
        @io         = io
        @queue      = SizedQueue.new(QUEUE_SIZE)
        @mutex      = Mutex.new
        @chunk      = nil
        @offset     = 0
        @eof        = false # whether the IO was read until the end
        @io_error   = nil   # raised while reading the IO
        @read_error = nil   # raised in the read callback
      end

      def process(&block)
        source = ::Vips::SourceCustom.new
        source.signal_connect("read") { |pointer, length| read(pointer, length) }

        worker = Thread.new do
          Thread.current.report_on_exception = false
          block.call(source)
        ensure
          @queue.close # stops reading the IO once libvips is done
        end

        feed
        worker.join
      rescue Exception
        # libvips fails when the IO can't be read, so report the cause instead
        raise @io_error || @read_error || $!
      else
        raise @io_error || @read_error if @io_error || @read_error
        worker.value
      ensure
        # unblocks libvips if we're interrupted, so the worker can finish
        @queue.close
      end

      private

      # Reads the IO and passes the chunks to libvips, until the IO is read
      # or libvips is done. Errors are recorded instead of raised, so that they
      # can be raised after libvips has failed.
      def feed
        while (chunk = @io.read(CHUNK_SIZE)) && !chunk.empty?
          chunk = chunk.b unless chunk.encoding == Encoding::BINARY
          @queue.push(chunk) # waits while libvips is behind
        end

        @eof = true
      rescue ClosedQueueError
        # libvips is done reading
      rescue Exception => error
        @io_error = error
      ensure
        @queue.close
      end

      # The read callback, called by libvips from its own threads. Like read(2),
      # it may read fewer bytes than requested, and returns the number of bytes
      # read, 0 on EOF or -1 on error. Exceptions need to be rescued here,
      # because ruby-vips turns them into EOF, which libvips would treat as a
      # truncated image rather than an error.
      def read(pointer, length)
        @mutex.synchronize do
          while @chunk.nil? || @offset == @chunk.bytesize
            @chunk, @offset = @queue.pop, 0

            # the queue is closed and empty, so the IO was either read until the
            # end, or reading it failed
            return @eof ? 0 : -1 unless @chunk
          end

          length = [length, @chunk.bytesize - @offset].min
          pointer.put_bytes(0, @chunk, @offset, length)
          @offset += length

          length
        end
      rescue Exception => error
        @read_error ||= error
        -1
      end
    end
  end
end
