begin
    require 'simplecov'
    require 'coveralls'
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
        [SimpleCov::Formatter::HTMLFormatter,
        Coveralls::SimpleCov::Formatter]
    )
    SimpleCov.start do
        add_filter "/test/"
    end
rescue LoadError
end

require 'minitest/autorun'
require 'fileutils'
require 'redirect_error'
require 'flexmock'
require 'flexmock/minitest_integration'


class FlexMock
  module Minitest
    def assertion_failed_error
      FlexMock.framework_adapter.assertion_failed_error
    end

    def check_failed_error
      FlexMock.framework_adapter.check_failed_error
    end

    # Assertion helper used to assert validation failure.  If a
    # message is given, then the error message should match the
    # expected error message.
    def assert_failure(klass, options={}, &block)
      message = options[:message]
      ex = assert_raises(klass) { yield }
      if message
        case message
        when Regexp
          assert_match message, ex.message
        when String
          assert ex.message.index(message), "Error message '#{ex.message}' should contain '#{message}'"
        end
      end
      ex
    end

    # Similar to assert_failure, but assumes that a mock generated
    # error object is return, so additional tests on the backtrace are
    # added.
    def assert_mock_failure(klass, options={}, &block)
      ex = assert_failure(klass, options, &block)
      file = if block.binding.respond_to?(:source_location)
               block.binding.source_location.first
             else
               eval("__FILE__", block.binding)
             end
      assert_matching_line(ex, file, options)
    end

    # Assert that there is a line matching file in the backtrace.
    # Options are:
    #
    #     deep: true -- matching line can be anywhere in backtrace,
    #                   otherwise it must be the first.
    #
    #     line: n    -- Add a line number to the match
    #
    def assert_matching_line(ex, file, options)
      line = options[:line]
      search_all = options[:deep]
      if line
        loc_re = /#{Regexp.quote(file)}:#{line}/
      else
        loc_re = Regexp.compile(Regexp.quote(file))
      end


      if search_all
        bts = ex.backtrace.join("\n")
        assert_with_block("expected a backtrace line to match #{loc_re}\nBACKTRACE:\n#{bts}") {
          ex.backtrace.any? { |bt| loc_re =~ bt }
        }
      else
        assert_match(loc_re, ex.backtrace.first, "BACKTRACE:\n  #{ex.backtrace.join("\n  ")}")
      end

      ex
    end

    def assert_with_block(msg=nil)
      unless yield
        assert(false, msg || "Expected block to yield true")
      end
    end

    def pending(msg="")
      state = "PASSING"
      begin
        yield
      rescue Exception => _
        state = "FAILING"
      end
      where = caller.first.split(/:in/).first
      puts "\n#{state} PENDING TEST (#{msg}) #{where}"
    end
  end
end
