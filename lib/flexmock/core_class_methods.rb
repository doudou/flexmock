#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'flexmock/noop'
require 'flexmock/mock_container'

class FlexMock
  class << self
    attr_reader :framework_adapter

    # Class method to make sure that verify is called at the end of a
    # test.  One mock object will be created for each name given to
    # the use method.  The mocks will be passed to the block as
    # arguments.  If no names are given, then a single anonymous mock
    # object will be created.
    #
    # At the end of the use block, each mock object will be verified
    # to make sure the proper number of calls have been made.
    #
    # Usage:
    #
    #   FlexMock.use("name") do |mock|    # Creates a mock named "name"
    #     mock.should_receive(:meth).
    #       returns(0).once
    #   end                               # mock is verified here
    #
    # NOTE: If you include FlexMock::TestCase into your test case
    # file, you can create mocks that will be automatically verified in
    # the test teardown by using the +flexmock+ method.
    #
    def use(*names)
      names = ["unknown"] if names.empty?
      container = UseContainer.new
      mocks = names.collect { |n| container.flexmock(n) }
      yield(*mocks)
    rescue Exception => _
      container.got_exception = true
      raise
    ensure
      container.flexmock_teardown
    end

    FORBID_MOCKING = :__flexmock_forbid_mocking

    # Forbid mock calls to happen while the block is being evaluated
    #
    # @param [Object] mocking_forbidden_return the return value that should be
    #   used if a mocking call has happened. If no mocking calls happened,
    #   returns the return value of the block
    def forbid_mocking(mocking_forbidden_return = nil)
      current, Thread.current[FORBID_MOCKING] =
          Thread.current[FORBID_MOCKING], true

      catch(FORBID_MOCKING) do
        return yield
      end
      mocking_forbidden_return

    ensure
      Thread.current[FORBID_MOCKING] = current
    end

    # Verify that mocking is allowed in the current context. Throws if it is
    # not.
    def verify_mocking_allowed!
      if Thread.current[FORBID_MOCKING]
        throw FORBID_MOCKING
      end
    end

    # Class method to format a method name and argument list as a nice
    # looking string.
    def format_call(sym, args)  # :nodoc:
      "#{sym}(#{format_args(args)})"
    end

    # Class method to format a list of args (the part between the
    # parenthesis).
    def format_args(args)
      if args
        args = args.map do |a|
          FlexMock.forbid_mocking("<recursive call to mocked method in #inspect>") do
            a.inspect
          end
        end
        args.join(', ')
      else
        "*args"
      end
    end

    # Check will assert the block returns true.  If it doesn't, an
    # assertion failure is triggered with the given message.
    def check(msg, &block)  # :nodoc:
      if FlexMock.framework_adapter.respond_to?(:check)
        FlexMock.framework_adapter.check(msg, &block)
      else
        FlexMock.framework_adapter.make_assertion(msg, &block)
      end
    end

  end

  # Container object to be used by the FlexMock.use method.
  class UseContainer
    include MockContainer

    attr_accessor :got_exception

    def initialize
      @got_exception = false
    end

    def passed?
      ! got_exception
    end
  end
end
