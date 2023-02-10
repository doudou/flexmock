class FlexMock

    module SpyDescribers
      def spy_description(spy, sym, args, kw, options)
        result = "have received "
        result << FlexMock.format_call(sym, args, kw)
        result << times_description(options[:times])
        result << block_description(options[:with_block])
        result
      end

      def describe_spy_expectation(spy, sym, args, kw, options={})
        describe_spy(spy, sym, args, kw, options)
      end

      def describe_spy_negative_expectation(spy, sym, args, kw, options={})
        describe_spy(spy, sym, args, kw, options, " NOT")
      end

      def describe_spy(spy, sym, args, kw, options, not_clause="")
        result = "expected "
        result << FlexMock.format_call(sym, args, kw)
        result << " to#{not_clause} be received by " << spy.inspect
        result << times_description(options[:times])
        result << block_description(options[:with_block])
        result << ".\n"
        result << describe_calls(spy)
        result
      end

      def describe_calls(spy)
        result = ''
        if spy.flexmock_calls.empty?
          result << "No messages have been received\n"
        else
          result << "The following messages have been received:\n"
          spy.flexmock_calls.each do |call_record|
            append_call_record(result, call_record)
          end
        end
        result
      end

      def append_call_record(result, call_record)
        result <<
          "    " <<
          FlexMock.format_call(call_record.method_name, call_record.args, call_record.kw)
        if call_record.expectation
          result <<
            " matched by " <<
            call_record.expectation.description
        end
        result << "\n"
      end

      def times_description(times)
        case times
        when 0
          " never"
        when 1
          " once"
        when 2
          " twice"
        when nil
          ""
        else
          " #{times} times"
        end
      end

      def block_description(needs_block)
        case needs_block
        when true
          " with a block"
        when false
          " without a block"
        else
          ""
        end
      end

      extend SpyDescribers
    end

end
