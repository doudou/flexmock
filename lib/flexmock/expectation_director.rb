#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'flexmock/noop'
require 'flexmock/errors'

class FlexMock

  # The expectation director is responsible for routing calls to the
  # correct expectations for a given argument list.
  #
  class ExpectationDirector

    # Create an ExpectationDirector for a mock object.
    def initialize(sym)
      @sym = sym
      @expectations = []
      @defaults = []
      @expected_order = nil
    end

    # Invoke the expectations for a given set of arguments.
    #
    # First, look for an expectation that matches the arguments and
    # is eligible to be called.  Failing that, look for a expectation
    # that matches the arguments (at this point it will be ineligible,
    # but at least we will get a good failure message).  Finally,
    # check for expectations that don't have any argument matching
    # criteria.
    def call(args, kw, block, call_record=nil)
      exp = find_expectation(args, kw, block)
      call_record.expectation = exp if call_record
      FlexMock.check(
        proc { "no matching handler found for " +
               FlexMock.format_call(@sym, args, kw) +
               "\nDefined expectations:\n  " +
               @expectations.map(&:description).join("\n  ") }
      ) { !exp.nil? }
      returned_value = exp.verify_call(args, kw, block)
      returned_value
    end

    # Append an expectation to this director.
    def <<(expectation)
      @expectations << expectation
    end

    # Find an expectation matching the given arguments.
    def find_expectation(args, kw, block) # :nodoc:
      if @expectations.empty?
        find_expectation_in(@defaults, args, kw, block)
      else
        find_expectation_in(@expectations, args, kw, block)
      end
    end

    # Do the post test verification for this director.  Check all the
    # expectations.  Only check the default expecatations if there are
    # no non-default expectations.
    def flexmock_verify         # :nodoc:
      (@expectations.empty? ? @defaults : @expectations).each do |exp|
        exp.flexmock_verify
      end
    end

    # Move the last defined expectation a default.
    def defaultify_expectation(exp) # :nodoc:
      last_exp = @expectations.last
      if last_exp != exp
        fail UsageError,
          "Cannot make a previously defined expection into a default"
      end
      @expectations.pop
      @defaults << exp
    end

    private

    def find_expectation_in(expectations, args, kw, block)
      expectations.find { |e| e.match_args(args, kw, block) && e.eligible? } ||
        expectations.find { |e| e.match_args(args, kw, block) }
    end
  end

end
