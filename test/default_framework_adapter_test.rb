#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require "test_helper"

class TestFlexmockDefaultFrameworkAdapter < Minitest::Test
  def setup
    @adapter = FlexMock::DefaultFrameworkAdapter.new
  end

  def test_assert_block_raises_exception
    assert_raises(FlexMock::DefaultFrameworkAdapter::AssertionFailedError) {
      @adapter.check("failure message") { false }
    }
  end

  def test_make_assertion_doesnt_raise_exception_when_making_assertion
    @adapter.check("failure message") { true }
  end
end
