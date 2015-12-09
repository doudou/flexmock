#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++



require 'flexmock/base'

class FlexMock
  if defined?(::RSpec)
    SpecModule = RSpec
  else
    SpecModule = Spec
  end

  class RSpecFrameworkAdapter
    def make_assertion(msg, &block)
      msg = msg.call if msg.is_a?(Proc)
      SpecModule::Expectations.fail_with(msg) unless yield
    end

    def check(msg, &block)
      make_assertion(msg, &block)
    end

    class AssertionFailedError < StandardError; end

    def assertion_failed_error
      SpecModule::Expectations::ExpectationNotMetError
    end
    def check_failed_error
      assertion_failed_error
    end
  end

  @framework_adapter = RSpecFrameworkAdapter.new
end

require 'flexmock/rspec_spy_matcher'
