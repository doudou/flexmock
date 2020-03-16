#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'minitest/autorun'
require "test_helper"

require "flexmock/base"
require "flexmock/minitest"

if defined?(Minitest::Test)
  class TestFlexmockMinitest < Minitest::Test
    include FlexMock::Minitest
  
    def before_teardown
      # flexmock should be teared down right now, and the teardown result should
      # be registered in the test failures (specific to minitest 5.0+)
      super
      if @should_fail
        assert 1, failures.size
      else
        assert 0, failures.size
      end
      # Clear failures ... otherwise the test will fail
      failures.clear
      assert @closed
    end
  end
else
  class TestFlexmockMinitest < MiniTest::Unit::TestCase
    include FlexMock::Minitest
  
    def before_teardown
      # flexmock should be teared down right now, but nothing should be raised
      # yet. The error will be raised in after_teardown
      super
      assert @closed
    end

    def after_teardown
      begin
        super
        failed = false
      rescue Exception
        failed = true
      end
      assert_equal @should_fail, failed, "Expected failed to be #{@should_fail}"
    end
  end
end

class TestFlexmockMinitest
  def flexmock_close
    @closed = true
    super
  end
  
  # This test should pass.
  def test_can_create_mocks
    m = flexmock("mock")
    m.should_receive(:hi).once
    m.hi
    @should_fail = false
  end
  
  # This test should fail during teardown.
  def test_should_fail__mocks_are_auto_verified
    m = flexmock("mock")
    m.should_receive(:hi).once
    @should_fail = true
  end
end

