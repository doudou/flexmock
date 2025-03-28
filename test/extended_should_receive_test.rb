#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require "test_helper"

module ExtendedShouldReceiveTests
  def test_accepts_expectation_hash
    @mock.should_receive( :foo => :bar, :baz => :froz )
    assert_equal :bar, @obj.foo
    assert_equal :froz, @obj.baz
  end

  def test_accepts_list_of_methods
    @mock.should_receive(:foo, :bar, "baz")
    assert_nil @obj.foo
    assert_nil @obj.bar
    assert_nil @obj.baz
  end

  def test_contraints_apply_to_all_expectations
    @mock.should_receive(:foo, :bar => :baz).with(1)
    assert_raises(check_failed_error) { @obj.foo(2) }
    assert_raises(check_failed_error) { @obj.bar(2) }
    assert_equal :baz, @obj.bar(1)
  end

  def test_count_contraints_apply_to_all_expectations
    @mock.should_receive(:foo, :bar => :baz).once
    @obj.foo
    assert_raises(assertion_failed_error) { @mock.flexmock_verify }
  end

  def test_multiple_should_receives_are_allowed
    @mock.should_receive(:hi).and_return(:bye).
      should_receive(:hello => :goodbye)
    assert_equal :bye, @obj.hi
    assert_equal :goodbye, @obj.hello
  end
end

class TestExtendedShouldReceiveOnFullMocks < Minitest::Test
  include FlexMock::Minitest
  include ExtendedShouldReceiveTests

  def setup
    @mock = flexmock("mock")
    @obj = @mock
  end

end

class TestExtendedShouldReceiveOnPartialMockProxies < Minitest::Test
  include FlexMock::Minitest
  include ExtendedShouldReceiveTests

  def setup
    @obj = Object.new
    @mock = flexmock(@obj, "mock")
  end

end
