require 'flexmock/spy_describers'

class FlexMock
  module TestUnitAssertions
    include FlexMock::SpyDescribers

    def assert_spy_called(spy, method_name, *args, **kw)
      _assert_spy_called(false, spy, method_name, *args, **kw)
    end

    def assert_spy_not_called(spy, method_name, *args, **kw)
      _assert_spy_called(true, spy, method_name, *args, **kw)
    end

    private

    def _assert_spy_called(negative, spy, method_name, *args, **kw)
      options = {}
      if method_name.is_a?(Hash)
        options = method_name
        method_name = args.shift
      end

      # Prior to ruby3, kw args would be matched in *args
      # thus, expecting any args (:_) implied also expecting
      # any kw args.
      kw = :_ if args == [:_]

      args = nil if args == [:_]
      kw = nil if kw == :_
      bool = spy.flexmock_received?(method_name, args, kw, options)
      if negative
        bool = !bool
        message = describe_spy_negative_expectation(spy, method_name, args, kw, options)
      else
        message = describe_spy_expectation(spy, method_name, args, kw, options)
      end
      assert bool, message
    end
  end
end
