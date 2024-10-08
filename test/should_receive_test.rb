#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'test_helper'

def mock_top_level_function
  :mtlf
end

module Kernel
  def mock_kernel_function
    :mkf
  end
end

# Used for testing
class Cat
  def purr
  end
  def meow
  end
end

class TestFlexMockShoulds < Minitest::Test
  include FlexMock::Minitest

  # Expected error messages on failures
  COUNT_ERROR_MESSAGE = /\bcalled\s+incorrect\s+number\s+of\s+times\b/
  NO_MATCH_ERROR_MESSAGE = /\bno\s+matching\s+handler\b/
  AT_LEAST_ERROR_MESSAGE = COUNT_ERROR_MESSAGE
  AT_MOST_ERROR_MESSAGE = COUNT_ERROR_MESSAGE
  OUT_OF_ORDER_ERROR_MESSAGE = /\bcalled\s+out\s+of\s+order\b/
  NON_CONTAINER_MESSAGE = /\bis\s+not\s+in\s+a\s+container\b/

  def test_defaults
    FlexMock.use do |m|
      m.should_receive(:hi)
      assert_nil m.hi
      assert_nil m.hi(1)
      assert_nil m.hi("hello", 2)
    end
  end

  def test_returns_with_value
    FlexMock.use do |m|
      m.should_receive(:hi).returns(1)
      assert_equal 1, m.hi
      assert_equal 1, m.hi(123)
    end
  end

  def test_returns_with_multiple_values
    FlexMock.use do |m|
      m.should_receive(:hi).and_return(1,2,3)
      assert_equal 1, m.hi
      assert_equal 2, m.hi
      assert_equal 3, m.hi
      assert_equal 3, m.hi
      assert_equal 3, m.hi
    end
  end

  def test_multiple_returns
    FlexMock.use do |m|
      m.should_receive(:hi).and_return(1).and_return(2,3)
      assert_equal 1, m.hi
      assert_equal 2, m.hi
      assert_equal 3, m.hi
      assert_equal 3, m.hi
      assert_equal 3, m.hi
    end
  end

  def test_returns_with_block
    FlexMock.use do |m|
      result = nil
      m.should_receive(:hi).with(Object).returns { |obj| result = obj }
      m.hi(3)
      assert_equal 3, result
    end
  end

  def test_with_block_example_from_readme
    FlexMock.use do |m|
      m.should_receive(:foo).with(Integer).with_block.and_return(:got_block)
      m.should_receive(:foo).with(Integer).and_return(:no_block)

      assert_equal :no_block, m.foo(1)
      assert_equal :got_block, m.foo(1) { }
    end
  end

  def test_with_no_block_example_from_readme
    FlexMock.use do |m|
      m.should_receive(:foo).with(Integer).with_no_block.and_return(:no_block)
      m.should_receive(:foo).with(Integer).and_return(:got_block)

      assert_equal :no_block, m.foo(1)
      assert_equal :got_block, m.foo(1) { }
    end
  end

  def test_with_optional_block
    FlexMock.use do |m|
      m.should_receive(:foo).with(Integer).with_optional_block.twice

      m.foo(1)
      m.foo(1) {}
    end
  end

  def test_return_with_and_without_block_interleaved
    FlexMock.use do |m|
      m.should_receive(:hi).and_return(:a).and_return { :b }.and_return(:c)
      assert_equal :a, m.hi
      assert_equal :b, m.hi
      assert_equal :c, m.hi
      assert_equal :c, m.hi
    end
  end

  def test_and_returns_alias
    FlexMock.use do |m|
      m.should_receive(:hi).and_return(4)
      assert_equal 4, m.hi
    end
  end

  def test_and_return_undefined
    FlexMock.use do |m|
      m.should_receive(:foo).and_return_undefined
      m.should_receive(:phoo).returns_undefined
      assert_equal FlexMock.undefined, m.foo
      assert_equal FlexMock.undefined, m.foo.bar.baz.bing.ka_ching
      assert_equal FlexMock.undefined, m.phoo.bar.baz.bing.ka_ching
    end
  end

  def test_and_yield_will_continue_to_yield_the_same_value
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:yield_value)
      assert_equal :yield_value, m.hi { |v| v }
      assert_equal :yield_value, m.hi { |v| v }
    end
  end

  def test_and_yield_with_multiple_values_yields_the_values
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:one, :two).once
      assert_equal [:one, :two], m.hi { |a, b| [a, b] }
    end
  end

  def test_multiple_yields_are_done_sequentially
    FlexMock.use do |m|
      m.should_receive(:msg).and_yield(:one).and_yield(:two)
      assert_equal :one, m.msg { |a| a }
      assert_equal :two, m.msg { |a| a }
      assert_equal :two, m.msg { |a| a }
    end
  end

  def test_multiple_yields_and_multiple_returns_are_synced
    FlexMock.use do |m|
      m.should_receive(:msg).and_yield(:one).and_return(1).and_yield(:two).and_return(2)
      yielded_values = []
      returned_values = []
      returned_values << m.msg { |a| yielded_values << a }
      returned_values << m.msg { |a| yielded_values << a }
      returned_values << m.msg { |a| yielded_values << a }
      assert_equal [:one, :two, :two], yielded_values
      assert_equal [1, 2, 2], returned_values
    end
  end

  def test_iteration_yields_values_in_sequence
    FlexMock.use do |m|
      m.should_receive(:msg).and_iterates(1, 2, 3)
      yielded_values = []
      m.msg { |a| yielded_values << a }
      assert_equal [1, 2, 3], yielded_values
    end
  end

  def test_iteration_and_yields_are_queued
    FlexMock.use do |m|
      m.should_receive(:msg).
          and_yield(:one).
          and_iterates(1, 2, 3).
          and_yield(:two)
      yielded_values = []
      yielded_values << m.enum_for(:msg).to_a
      yielded_values << m.enum_for(:msg).to_a
      yielded_values << m.enum_for(:msg).to_a
      assert_equal [[:one], [1, 2, 3], [:two]], yielded_values
    end
  end

  def test_failure_if_no_block_given
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:one, :two).once
      assert_raises(FlexMock::MockError) do m.hi end
    end
  end

  def test_failure_different_return_value_than_yield_return
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:yld).once.and_return(:ret)
      yielded_value = nil
      assert_equal :ret, m.hi { |v| yielded_value = v }
      assert_equal :yld, yielded_value
    end
  end

  def test_multiple_yields
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:one, :two).and_yield(1, 2)
      assert_equal [:one, :two], m.hi { |a, b| [a, b] }
      assert_equal [1, 2], m.hi { |a, b| [a, b] }
    end
  end

  def test_multiple_yields_will_yield_the_last_value_set
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:a).and_yield(:b)
      assert_equal [:a], m.hi { |a, b| [a] }
      assert_equal [:b], m.hi { |a, b| [a] }
      assert_equal [:b], m.hi { |a, b| [a] }
      assert_equal [:b], m.hi { |a, b| [a] }
      assert_equal [:b], m.hi { |a, b| [a] }
    end
  end

  def test_yielding_then_not_yielding_and_then_yielding_again
    FlexMock.use do |m|
      m.should_receive(:hi).and_yield(:a).once
      m.should_receive(:hi).and_return(:b).once
      m.should_receive(:hi).and_yield(:c).once
      assert_equal :a, m.hi { |v| v }
      assert_equal :b, m.hi
      assert_equal :c, m.hi { |v| v }
    end
  end

  def test_yields_syntax
    FlexMock.use do |m|
      m.should_receive(:hi).yields(:one)
      assert_equal :one, m.hi { |a| a }
    end
  end

  class MyError < RuntimeError
  end

  def test_and_raises_with_exception_class_throws_exception
    FlexMock.use do |m|
      m.should_receive(:failure).and_raise(MyError)
      assert_raises MyError do
        m.failure
      end
    end
  end

  def test_and_raises_with_arguments_throws_exception_made_with_args
    FlexMock.use do |m|
      m.should_receive(:failure).and_raise(MyError, "my message")
      ex = assert_raises MyError do
        m.failure
      end
      assert_equal "my message", ex.message
    end
  end

  def test_and_raises_with_a_specific_exception_throws_the_exception
    FlexMock.use do |m|
      err = MyError.new
      m.should_receive(:failure).and_raise(err)
      ex = assert_raises MyError do
        m.failure
      end
      assert_equal err, ex
    end
  end

  def test_raises_is_an_alias_for_and_raise
    FlexMock.use do |m|
      m.should_receive(:failure).raises(RuntimeError)
      assert_raises RuntimeError do
        m.failure
      end
    end
  end

  def test_multiple_and_raise_clauses_will_be_done_sequentially
    FlexMock.use do |m|
      m.should_receive(:failure).
        and_raise(RuntimeError, "ONE").
        and_raise(RuntimeError, "TWO")
      ex = assert_raises RuntimeError do m.failure end
      assert_equal "ONE", ex.message
      ex = assert_raises RuntimeError do m.failure end
      assert_equal "TWO", ex.message
    end
  end

  def test_and_throw_will_throw_a_symbol
    FlexMock.use do |m|
      m.should_receive(:msg).and_throw(:sym)
      value = catch(:sym) do
        m.msg
        fail "Should not reach this line"
      end
      assert_nil value
    end
  end

  def test_and_throw_with_expression_will_throw
    FlexMock.use do |m|
      m.should_receive(:msg).and_throw(:sym, :return_value)
      value = catch(:sym) do
        m.msg
        fail "Should not reach this line"
      end
      assert_equal :return_value, value
    end
  end

  def test_throws_is_an_alias_for_and_throw
    FlexMock.use do |m|
      m.should_receive(:msg).throws(:sym, :return_value)
      value = catch(:sym) do
        m.msg
        fail "Should not reach this line"
      end
      assert_equal :return_value, value
    end
  end

  def test_multiple_throws_will_be_done_sequentially
    FlexMock.use do |m|
      m.should_receive(:toss).
        and_throw(:sym, "ONE").
        and_throw(:sym, "TWO")
      value = catch(:sym) do m.toss end
      assert_equal "ONE", value
      value = catch(:sym) do m.toss end
      assert_equal "TWO", value
    end
  end

  def test_pass_thru_just_returns_undefined_on_mocks
    FlexMock.use do |m|
      m.should_receive(:hi).pass_thru
      assert_equal FlexMock.undefined, m.hi
    end
  end

  def test_multiple_expectations
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10)
      m.should_receive(:hi).with(2).returns(20)

      assert_equal 10, m.hi(1)
      assert_equal 20, m.hi(2)
    end
  end

  def test_with_no_args_with_no_args
    FlexMock.use do |m|
      m.should_receive(:hi).with_no_args
      m.hi
    end
  end

  def test_with_no_args_but_with_args
    assert_mock_failure(check_failed_error, :message =>NO_MATCH_ERROR_MESSAGE, :deep => true) do
      FlexMock.use do |m|
        m.should_receive(:hi).with_no_args
        m.hi(1)
      end
    end
  end

  def test_with_any_args
    FlexMock.use do |m|
      m.should_receive(:hi).with_any_args
      m.hi
      m.hi(1)
      m.hi(1,2,3)
      m.hi("this is a test")
    end
  end

  def test_with_any_single_arg_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(1,FlexMock.any).twice
      m.hi(1,2)
      m.hi(1, "this is a test")
    end
  end

  def test_with_any_single_arg_nonmatching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).times(3)
      m.should_receive(:hi).with(1,FlexMock.any).never
      m.hi
      m.hi(1)
      m.hi(1, "hi", nil)
    end
  end

  def test_with_equal_arg_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.eq(Object)).once
      m.hi(Object)
    end
  end

  def test_with_ducktype_arg_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.ducktype(:purr, :meow)).once
      m.hi(Cat.new)
    end
  end

  def test_with_ducktype_arg_matching_no_match
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.ducktype(:purr, :meow, :growl))
      assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+1) {
        m.hi(Cat.new)
      }
    end
  end

  def test_with_kw_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(1, a: 2).once
      m.hi(1, a: 2)
    end

    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with_kw_args(FlexMock.hsh(:a => 1, :b => 2)).once
      m.hi(:a => 1, :b => 2, :c => 3)
    end
  end

  def test_with_kw_not_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(1, a: 2)
      assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+1) {
        m.hi(1, a: 2, b: 3)
      }
    end
  end

  def test_with_hash_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.hsh(:a => 1, :b => 2)).once
      m.hi({:a => 1, :b => 2, :c => 3}, **{})
    end
  end

  def test_with_hash_non_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.hsh(:a => 1, :b => 2))
      assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+1) {
        m.hi({:a => 1, :b => 4, :c => 3}, **{})
      }
    end
  end

  def test_with_equal_arg_nonmatching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.eq(Object)).never
      m.should_receive(:hi).never
      m.should_receive(:hi).with(1).once
      m.hi(1)
    end
  end

  def test_with_arbitrary_arg_matching
    FlexMock.use('greeter') do |m|
      m.should_receive(:hi).with(FlexMock.on { |arg| arg % 2 == 0 rescue nil }).twice
      m.should_receive(:hi).never
      m.should_receive(:hi).with(1).once
      m.should_receive(:hi).with(2).never
      m.should_receive(:hi).with(3).once
      m.should_receive(:hi).with(4).never
      m.hi(1)
      m.hi(2)
      m.hi(3)
      m.hi(4)
    end
  end

  def test_args_matching_with_regex
    FlexMock.use do |m|
      m.should_receive(:hi).with(/one/).returns(10)
      m.should_receive(:hi).with(/t/).returns(20)

      assert_equal 10, m.hi("one")
      assert_equal 10, m.hi("done")
      assert_equal 20, m.hi("two")
      assert_equal 20, m.hi("three")
    end
  end

  def test_arg_matching_with_regex_matching_non_string
    FlexMock.use do |m|
      m.should_receive(:hi).with(/1/).returns(10)
      assert_equal 10, m.hi(319)
    end
  end

  def test_arg_matching_with_class
    FlexMock.use do |m|
      m.should_receive(:hi).with(0.class).returns(10)
      m.should_receive(:hi).with(Object).returns(20)

      assert_equal 10, m.hi(319)
      assert_equal 10, m.hi(0.class)
      assert_equal 20, m.hi("hi")
    end
  end

  def test_arg_matching_with_no_match
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10)
      assert_mock_failure(check_failed_error, :message =>NO_MATCH_ERROR_MESSAGE, :deep => true, :line => __LINE__+1) {
        m.hi(2)
      }
    end
  end

  def test_arg_matching_with_string_doesnt_over_match
    FlexMock.use do |m|
      m.should_receive(:hi).with(String).returns(20)
      assert_mock_failure(check_failed_error, :message =>NO_MATCH_ERROR_MESSAGE, :deep => true, :line => __LINE__+1) {
        m.hi(1.0)
      }
    end
  end

  def test_block_arg_given_to_no_block
    FlexMock.use do |m|
      m.should_receive(:hi).with_no_block.returns(20)
      assert_mock_failure(check_failed_error, :message =>NO_MATCH_ERROR_MESSAGE, :deep => true, :line => __LINE__+1) {
        m.hi { 1 }
      }
    end
  end

  def test_block_arg_given_to_matching_proc
    FlexMock.use do |m|
      arg = nil
      m.should_receive(:hi)
       .with_block.once
       .and_return { |&block| arg = block; block.call }
      result = m.hi { 1 }
      assert_equal 1, arg.call
      assert_equal 1, result
    end
  end

  def test_arg_matching_precedence_when_best_first
    FlexMock.use("greeter") do |m|
      m.should_receive(:hi).with(1).once
      m.should_receive(:hi).with(FlexMock.any).never
      m.hi(1)
    end
  end

  def test_arg_matching_precedence_when_best_last_but_still_matches_first
    FlexMock.use("greeter") do |m|
      m.should_receive(:hi).with(FlexMock.any).once
      m.should_receive(:hi).with(1).never
      m.hi(1)
    end
  end

  def test_never_and_never_called
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).never
    end
  end

  def test_never_and_called_once
    assert_mock_failure(check_failed_error, :message =>COUNT_ERROR_MESSAGE, :deep => true, :line => __LINE__+3) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).never
        m.hi(1)
      end
    end
  end

  def test_once_called_once
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).once
      m.hi(1)
    end
  end

  def test_once_but_never_called
    assert_mock_failure(assertion_failed_error, :message =>COUNT_ERROR_MESSAGE, :line => __LINE__+2) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).once
      end
    end
  end

  def test_once_but_called_twice
    assert_mock_failure(check_failed_error, :message =>COUNT_ERROR_MESSAGE, :line => __LINE__+4) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).once
        m.hi(1)
        m.hi(1)
      end
    end
  end

  def test_twice_and_called_twice
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).twice
      m.hi(1)
      m.hi(1)
    end
  end

  def test_zero_or_more_called_zero
    FlexMock.use do |m|
      m.should_receive(:hi).zero_or_more_times
    end
  end

  def test_zero_or_more_called_once
    FlexMock.use do |m|
      m.should_receive(:hi).zero_or_more_times
      m.hi
    end
  end

  def test_zero_or_more_called_100
    FlexMock.use do |m|
      m.should_receive(:hi).zero_or_more_times
      100.times { m.hi }
    end
  end

  def test_times
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).times(10)
      10.times { m.hi(1) }
    end
  end

  def test_at_least_called_once
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).at_least.once
      m.hi(1)
    end
  end

  def test_at_least_but_never_called
    assert_mock_failure(assertion_failed_error, :message =>AT_LEAST_ERROR_MESSAGE, :line => __LINE__+2) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).at_least.once
      end
    end
  end

  def test_at_least_once_but_called_twice
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).at_least.once
      m.hi(1)
      m.hi(1)
    end
  end

  def test_at_least_and_exact
    assert_mock_failure(check_failed_error, :message =>COUNT_ERROR_MESSAGE, :line => __LINE__+4) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).at_least.once.once
        m.hi(1)
        m.hi(1)
      end
    end
  end

  def test_at_most_but_never_called
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).at_most.once
    end
  end

  def test_at_most_called_once
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).at_most.once
      m.hi(1)
    end
  end

  def test_at_most_called_twice
    ex = assert_mock_failure(check_failed_error, :message =>AT_MOST_ERROR_MESSAGE, :line => __LINE__+4) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).at_most.once
        m.hi(1)
        m.hi(1)
      end
    end
    assert_match(/at most 1/i, ex.message)
  end

  def test_at_most_and_at_least_called_never
    ex = assert_mock_failure(assertion_failed_error, :message =>AT_LEAST_ERROR_MESSAGE, :line => __LINE__+2) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).at_least.once.at_most.twice
      end
    end
    assert_match(/at least 1/i, ex.message)
  end

  def test_at_most_and_at_least_called_once
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).at_least.once.at_most.twice
      m.hi(1)
    end
  end

  def test_at_most_and_at_least_called_twice
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).returns(10).at_least.once.at_most.twice
      m.hi(1)
      m.hi(1)
    end
  end

  def test_at_most_and_at_least_called_three_times
    assert_mock_failure(check_failed_error, :message =>AT_MOST_ERROR_MESSAGE, :line => __LINE__+5) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).returns(10).at_least.once.at_most.twice
        m.hi(1)
        m.hi(1)
        m.hi(1)
      end
    end
  end

  def test_call_counts_only_apply_to_matching_args
    FlexMock.use do |m|
      m.should_receive(:hi).with(1).once
      m.should_receive(:hi).with(2).twice
      m.should_receive(:hi).with(3)
      m.hi(1)
      m.hi(2)
      m.hi(2)
      20.times { m.hi(3) }
    end
  end

  def test_call_counts_only_apply_to_matching_args_with_mismatch
    ex = assert_mock_failure(assertion_failed_error, :message =>COUNT_ERROR_MESSAGE, :line => __LINE__+3) do
      FlexMock.use do |m|
        m.should_receive(:hi).with(1).once
        m.should_receive(:hi).with(2).twice
        m.should_receive(:hi).with(3)
        m.should_receive(:lo)
        m.hi(1)
        m.hi(2)
        m.lo
        20.times { m.hi(3) }
      end
    end
    assert_match(/hi\(2\)/, ex.message)
  end

  def test_ordered_calls_in_order_will_pass
    FlexMock.use 'm' do |m|
      m.should_receive(:hi).ordered
      m.should_receive(:lo).ordered

      m.hi
      m.lo
    end
  end

  def test_ordered_calls_out_of_order_will_fail
    assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use 'm' do |m|
        m.should_receive(:hi).ordered
        m.should_receive(:lo).ordered

        m.lo
        m.hi
      end
    end
  end

  def test_failure_in_ordered_calls_combined_with_valid_count_will_report_an_order_failure
    assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use 'm', 'n' do |m, n|
        m.should_receive(:hi).once.globally.ordered
        n.should_receive(:lo).once.globally.ordered

        n.lo
        m.hi
      end
    end
  end

  def test_order_calls_with_different_arg_lists_and_in_order_will_pass
    FlexMock.use 'm' do |m|
      m.should_receive(:hi).with("one").ordered
      m.should_receive(:hi).with("two").ordered

      m.hi("one")
      m.hi("two")
    end
  end

  def test_order_calls_with_different_arg_lists_and_out_of_order_will_fail
    assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use 'm' do |m|
        m.should_receive(:hi).with("one").ordered
        m.should_receive(:hi).with("two").ordered

        m.hi("two")
        m.hi("one")
      end
    end
  end

  def test_unordered_calls_do_not_effect_ordered_testing
    FlexMock.use 'm' do |m|
      m.should_receive(:blah)
      m.should_receive(:hi).ordered
      m.should_receive(:lo).ordered

      m.blah
      m.hi
      m.blah
      m.lo
      m.blah
    end
  end

  def test_ordered_with_multiple_calls_will_pass
    FlexMock.use 'm' do |m|
      m.should_receive(:hi).ordered
      m.should_receive(:lo).ordered

      m.hi
      m.hi
      m.lo
      m.lo
    end
  end

  def test_grouped_ordering_with_numbers
    FlexMock.use 'm' do |m|
      m.should_receive(:start).ordered(1)
      m.should_receive(:flip).ordered(2)
      m.should_receive(:flop).ordered(2)
      m.should_receive(:final).ordered

      m.start
      m.flop
      m.flip
      m.flop
      m.final
    end
  end

  def test_grouped_ordering_with_symbols
    FlexMock.use 'm' do |m|
      m.should_receive(:start).ordered(:start_group)
      m.should_receive(:flip).ordered(:flip_flop_group)
      m.should_receive(:flop).ordered(:flip_flop_group)
      m.should_receive(:final).ordered

      m.start
      m.flop
      m.flip
      m.flop
      m.final
    end
  end

  def test_global_ordering_message_includes_received_calls
    e = assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use 'm' do |m|
        m.should_receive(:one).globally.ordered
        m.should_receive(:two).globally.ordered
        m.one
        m.two
        m.one
      end
    end
    assert_match(/one\(\) matched by should_receive\(:one\)/, e.message)
    assert_match(/two\(\) matched by should_receive\(:two\)/, e.message)
    assert_match(/one\(\) matched by should_receive\(:one\)/, e.message)
  end

  def test_ordering_message_includes_received_calls
    e = assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use 'm' do |m|
        m.should_receive(:one).ordered
        m.should_receive(:two).ordered
        m.one
        m.two
        m.one
      end
    end
    assert_match(/one\(\) matched by should_receive\(:one\)/, e.message)
    assert_match(/two\(\) matched by should_receive\(:two\)/, e.message)
    assert_match(/one\(\) matched by should_receive\(:one\)/, e.message)
  end

  def test_explicit_ordering_mixed_with_implicit_ordering_should_not_overlap
    FlexMock.use 'm' do |m|
      xstart = m.should_receive(:start).ordered
      xmid = m.should_receive(:mid).ordered(:group_name)
      xend = m.should_receive(:end).ordered
      assert xstart.order_number < xmid.order_number
      assert xmid.order_number < xend.order_number
    end
  end

  def test_explicit_ordering_with_explicit_misorders
    assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use 'm' do |m|
        m.should_receive(:hi).ordered(:first_group)
        m.should_receive(:lo).ordered(:second_group)

        m.lo
        m.hi
      end
    end
    # TODO: It would be nice to get the group names in the error message.
    # assert_match /first_group/, ex.message
    # assert_match /second_group/, ex.message
  end

  # Test submitted by Mikael Pahmp to correct expectation matching.
  def test_ordering_with_explicit_no_args_matches_correctly
    FlexMock.use("m") do |m|
      m.should_receive(:foo).with_no_args.once.ordered
      m.should_receive(:bar).with_no_args.once.ordered
      m.should_receive(:foo).with_no_args.once.ordered
      m.foo
      m.bar
      m.foo
    end
  end

  # Test submitted by Mikael Pahmp to correct expectation matching.
  def test_ordering_with_any_arg_matching_correctly_matches
    FlexMock.use("m") do |m|
      m.should_receive(:foo).with_any_args.once.ordered
      m.should_receive(:bar).with_any_args.once.ordered
      m.should_receive(:foo).with_any_args.once.ordered
      m.foo
      m.bar
      m.foo
    end
  end

  def test_ordering_between_mocks_is_not_normally_defined
    FlexMock.use("x", "y") do |x, y|
      x.should_receive(:one).ordered
      y.should_receive(:two).ordered

      y.two
      x.one
    end
  end

  def test_ordering_between_mocks_is_honored_for_global_ordering
    assert_mock_failure(check_failed_error, :message =>OUT_OF_ORDER_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use("x", "y") do |x, y|
        x.should_receive(:one).globally.ordered
        y.should_receive(:two).globally.ordered

        y.two
        x.one
      end
    end
  end

  def test_ordering_is_verified_after_eligibility
    assert_mock_failure(check_failed_error, :message =>COUNT_ERROR_MESSAGE, :deep => true, :line => __LINE__+6) do
      FlexMock.use("x", "y") do |x, y|
        x.should_receive(:one).once.ordered
        x.should_receive(:two).ordered
        x.one
        x.two
        x.one
      end
    end
  end

  def test_expectation_formating
    mock = flexmock("m")
    exp = mock.should_receive(:f).with(1,"two", /^3$/).
      and_return(0).at_least.once

    mock.f(1, "two", 3)
    assert_equal 'f(1, "two", /^3$/)', exp.to_s
  end

  def test_multi_expectation_formatting
    mock = flexmock("mock")
    exp = mock.should_receive(:f, :g).with(1)
    assert_equal "[f(1), g(1)]", exp.to_s
  end

  def test_explicit_ordering_with_limits_allow_multiple_return_values
    FlexMock.use('mock') do |m|
      m.should_receive(:f).with(2).once.and_return { :first_time }
      m.should_receive(:f).with(2).twice.and_return { :second_or_third_time }
      m.should_receive(:f).with(2).and_return { :forever }

      assert_equal :first_time, m.f(2)
      assert_equal :second_or_third_time, m.f(2)
      assert_equal :second_or_third_time, m.f(2)
      assert_equal :forever, m.f(2)
      assert_equal :forever, m.f(2)
      assert_equal :forever, m.f(2)
      assert_equal :forever, m.f(2)
      assert_equal :forever, m.f(2)
      assert_equal :forever, m.f(2)
      assert_equal :forever, m.f(2)
    end
  end

  def test_global_methods_can_be_mocked
    m = flexmock("m")
    m.should_receive(:mock_top_level_function).and_return(:mock)
    assert_equal :mock, m.mock_top_level_function
  end

  def test_kernel_methods_can_be_mocked
    m = flexmock("m")
    m.should_receive(:mock_kernel_function).and_return(:mock)
    assert_equal :mock, m.mock_kernel_function
  end

  def test_undefing_kernel_methods_dont_effect_other_mocks
    m = flexmock("m")
    m2 = flexmock("m2")
    m.should_receive(:mock_kernel_function).and_return(:mock)
    assert_equal :mock, m.mock_kernel_function
    assert_equal :mkf, m2.mock_kernel_function
  end

  def test_expectations_can_by_marked_as_default
    m = flexmock("m")
    m.should_receive(:foo).and_return(:bar).by_default
    assert_equal :bar, m.foo
  end

  def test_default_expectations_are_search_in_the_proper_order
    m = flexmock("m")
    m.should_receive(:foo).with(Integer).once.and_return(:first).by_default
    m.should_receive(:foo).with(1).and_return(:second).by_default
    assert_equal :first, m.foo(1)
    assert_equal :second, m.foo(1)
  end

  def test_expectations_with_count_constraints_can_by_marked_as_default
    m = flexmock("m")
    m.should_receive(:foo).and_return(:bar).once.by_default
    assert_raises assertion_failed_error do
      flexmock_teardown
    end
  end

  def test_default_expectations_are_overridden_by_later_expectations
    m = flexmock("m")
    m.should_receive(:foo).and_return(:bar).once.by_default
    m.should_receive(:foo).and_return(:bar).twice
    m.foo
    m.foo
  end

  def test_default_expectations_can_be_changed_by_later_expectations
    m = flexmock("m")
    m.should_receive(:foo).with(1).and_return(:bar).once.by_default
    m.should_receive(:foo).with(2).and_return(:baz).once
    assert_raises check_failed_error do
      # This expectation should be hidded by the non-result
      m.foo(1)
    end
    m.foo(2)
  end

  def test_ordered_default_expectations_can_be_specified
    m = flexmock("m")
    m.should_receive(:foo).ordered.by_default
    m.should_receive(:bar).ordered.by_default
    m.bar
    assert_raises check_failed_error do m.foo end
  end

  def test_ordered_default_expectations_can_be_overridden
    m = flexmock("m")
    m.should_receive(:foo).ordered.by_default
    m.should_receive(:bar).ordered.by_default

    m.should_receive(:bar).ordered
    m.should_receive(:foo).ordered

    m.bar
    m.foo
  end

  def test_by_default_works_at_mock_level
    m = flexmock("m",
      :foo => :bar,
      :pooh => :bear,
      :who  => :dey).by_default
    m.should_receive(:pooh => :winnie)
    assert_equal :bar, m.foo
    assert_equal :dey, m.who
    assert_equal :winnie, m.pooh
  end

  def test_by_default_at_mock_level_does_nothing_with_no_expectations
    flexmock("m").by_default
  end

  def test_partial_mocks_can_have_default_expectations
    obj = Object.new
    flexmock(obj).should_receive(:foo).and_return(:bar).by_default
    assert_equal :bar, obj.foo
  end

  def test_partial_mocks_can_have_default_expectations_overridden
    obj = Object.new
    flexmock(obj).should_receive(:foo).and_return(:bar).by_default
    flexmock(obj).should_receive(:foo).and_return(:baz)
    assert_equal :baz, obj.foo
  end

  def test_wicked_and_evil_tricks_with_by_default_are_thwarted
    mock = flexmock("mock")
    exp = mock.should_receive(:foo).and_return(:first).once
    mock.should_receive(:foo).and_return(:second)
    ex = assert_raises(FlexMock::UsageError) do
      exp.by_default
    end
    assert_match %r(previously defined), ex.message
    assert_equal :first, mock.foo
    assert_equal :second, mock.foo
  end

  def test_mocks_can_handle_multi_parameter_respond_tos
    mock = flexmock("a mock", :foo => :bar)
    assert mock.respond_to?(:foo)
    assert mock.respond_to?(:foo, true)
    assert mock.respond_to?(:foo, false)

    assert ! mock.respond_to?(:phoo)
    assert ! mock.respond_to?(:phoo, false)
    assert ! mock.respond_to?(:phoo, true)
  end

  def test_backtraces_point_to_should_receive_line
    mock = flexmock("a mock")
    file_name_re = Regexp.quote(__FILE__)
    line_no = __LINE__ + 1
    mock.should_receive(:foo).and_return(:bar).once
    begin
      flexmock_verify
    rescue Exception => ex
      exception = ex
    end
    refute_nil exception
    assert_match(/#{file_name_re}:#{line_no}/, exception.backtrace.first)
  end

  def test_can_mock_operators
    assert_operator(:[]) { |m| m[1] }
    assert_operator(:[]=) { |m| m[1] = :value }
    assert_operator(:**) { |m| m ** :x }
    assert_operator(:+@) { |m| +m }
    assert_operator(:-@) { |m| -m }
    assert_operator(:+) { |m| m + :x }
    assert_operator(:-) { |m| m - :x }
    assert_operator(:*) { |m| m * :x }
    assert_operator(:"/") { |m| m / :x }
    assert_operator(:%) { |m| m % :x }
    assert_operator(:~) { |m| ~m }  # )
    assert_operator(:&) { |m| m & :x }
    assert_operator(:|) { |m| m | :x }
    assert_operator(:^) { |m| m ^ :x }
    assert_operator(:<) { |m| m < :x }
    assert_operator(:>) { |m| m > :x }
    assert_operator(:>=) { |m| m >= :x }
    assert_operator(:<=) { |m| m <= :x }
    assert_operator(:==) { |m| m == :x }
    assert_operator(:===) { |m| m === :x }
    assert_operator(:<<) { |m| m << :x }
    assert_operator(:>>) { |m| m >> :x }
    assert_operator(:<=>) { |m| m <=> :x }
    assert_operator(:=~) { |m| m =~ :x }
    assert_operator(:"`") { |m| m.`("command") } # `
  end

  def test_with_signature_required_arguments
    FlexMock.use do |mock|
      mock.should_receive(:m).with_signature(required_arguments: 2)
      assert_mock_failure(check_failed_error, message: /expects at least 2 positional arguments but got only 1/, line: __LINE__+1) do
        mock.m(1)
      end
      mock.m(1, 2)
      assert_mock_failure(check_failed_error, message: /expects at most 2 positional arguments but got 3/, line: __LINE__+1) do
        mock.m(1, 2, 3)
      end
    end
  end

  def test_a_proc_argument_last_is_not_interpreted_as_positional_argument
    FlexMock.use do |mock|
      mock.should_receive(:m).with_signature(required_arguments: 2)
      mock.m(1, 2) { }

      assert_raises(FlexMock::CheckFailedError) do
        mock.m(1) { }
      end
    end
  end

  def test_with_signature_optional_arguments
    FlexMock.use do |mock|
      mock.should_receive(:m).with_signature(required_arguments: 2, optional_arguments: 2)
      assert_mock_failure(check_failed_error, message: /expects at least 2 positional arguments but got only 1/, line: __LINE__+1) do
        mock.m(1)
      end
      mock.m(1, 2)
      mock.m(1, 2, 3)
      mock.m(1, 2, 3, 4)
      assert_mock_failure(check_failed_error, message: /expects at most 4 positional arguments but got 5/, line: __LINE__+1) do
        mock.m(1, 2, 3, 4, 5)
      end
    end
  end

  def test_with_signature_splat_validates_required_arguments
    FlexMock.use do |mock|
      mock = flexmock
      mock.should_receive(:m).with_signature(required_arguments: 2, optional_arguments: 2, splat: true)
      assert_mock_failure(check_failed_error, message: /expects at least 2 positional arguments but got only 1/, line: __LINE__+1) do
        mock.m(1)
      end
    end
  end

  def test_with_signature_splat_allows_an_arbitrary_number_of_extra_arguments
    FlexMock.use do |mock|
      mock = flexmock
      mock.should_receive(:m).with_signature(required_arguments: 2, optional_arguments: 2, splat: true)
      mock.m(1, 2)
      mock.m(1, 2, 3)
      mock.m(1, 2, 3, 4)
    end
  end

  def test_with_signature_required_keyword_arguments
    FlexMock.use do |mock|
      mock = flexmock
      mock.should_receive(:m).
        with_signature(required_keyword_arguments: [:a, :b])
      assert_mock_failure(check_failed_error, message: /missing required keyword arguments a/, line: __LINE__+1) do
        mock.m(b: 10)
      end
      mock.m(a: 10, b: 20)
      assert_mock_failure(check_failed_error, message: /given unexpected keyword argument c/, line: __LINE__+1) do
        mock.m(a: 10, b: 10, c: 20)
      end
    end
  end

  def test_with_signature_optional_keyword_arguments
    FlexMock.use do |mock|
      mock.should_receive(:m).
        with_signature(required_keyword_arguments: [:a, :b], optional_keyword_arguments: [:c, :d])
      assert_mock_failure(check_failed_error, message: /missing required keyword arguments a/, line: __LINE__+1) do
        mock.m(b: 10)
      end
      mock.m(a: 10, b: 20)
      mock.m(a: 10, b: 20, c: 30)
      mock.m(a: 10, b: 20, c: 30, d: 40)
      assert_mock_failure(check_failed_error, message: /given unexpected keyword argument e/, line: __LINE__+1) do
        mock.m(a: 10, b: 10, e: 42)
      end
    end
  end

  def test_with_signature_keyword_splat
    FlexMock.use do |mock|
      mock.should_receive(:m).
        with_signature(
          required_keyword_arguments: [:a, :b],
          optional_keyword_arguments: [:c, :d],
          keyword_splat: true)
      assert_mock_failure(check_failed_error, message: /missing required keyword arguments a/, line: __LINE__+1) do
        mock.m(b: 10)
      end
      mock.m(a: 10, b: 20)
      mock.m(a: 10, b: 20, c: 30)
      mock.m(a: 10, b: 20, c: 30, d: 40)
      mock.m(a: 10, b: 10, e: 42)
    end
  end

  def test_with_signature_raises_if_no_keywords_are_given
    FlexMock.use do |mock|
      mock.should_receive(:m).
        with_signature(required_keyword_arguments: [:b], required_arguments: 1)
      assert_mock_failure(check_failed_error, message: /expects keyword arguments but none were provided/, line: __LINE__+1) do
        mock.m(10)
      end
    end
  end

  def test_with_signature_handles_getting_a_basicobject_as_last_object
    FlexMock.use do |mock|
      mock.should_receive(:m).
          with_signature(optional_arguments: 1, required_keyword_arguments: [:b])
      assert_mock_failure(check_failed_error, message: /expects keyword arguments but none were provided/, line: __LINE__+1) do
        mock.m(BasicObject.new)
      end
    end
  end
  def test_with_signature_removes_the_keywords_from_the_position_arguments
    FlexMock.use do |mock|
      mock.should_receive(:m).
        with_signature(required_keyword_arguments: [:b], required_arguments: 1)
      mock.m(10, b: 10)
    end

    FlexMock.use do |mock|
      mock.should_receive(:m).
        with_signature(optional_keyword_arguments: [:b], required_arguments: 1)
      mock.m(10, b: 10)
    end

    FlexMock.use do |mock|
      mock.should_receive(:m).
        with_signature(keyword_splat: true, required_arguments: 1)
      mock.m(10, b: 10)
    end
  end

  def test_signature_validator_understands_that_a_proc_last_can_both_be_a_positional_parameter_and_a_block
      FlexMock.use do |mock|
        mock.should_receive(:m).with_signature(required_arguments: 1)
        mock.m(proc { })
      end

      FlexMock.use do |mock|
        mock.should_receive(:m).with_signature(required_arguments: 0)
        mock.m { }
      end
  end

  def test_signature_validator_interprets_keyword_arguments_even_if_a_block_is_provided
      FlexMock.use do |mock|
        mock.should_receive(:m).with_signature(required_arguments: 1, optional_keyword_arguments: [:b])
        mock.m(10, b: 10) { }
      end
  end

  def test_signature_validator_does_not_interpret_a_proc_as_positional_argument_if_keyword_arguments_are_expected
      FlexMock.use do |mock|
        mock.should_receive(:m).with_signature(required_arguments: 1, required_keyword_arguments: [:b])
        mock.m(10, b: 10) { }
        signature = if RUBY_VERSION < "3"
                      'm\(\*args\)'
                    else
                      'm\(\*args, \*\*kwargs\)'
                    end
        assert_mock_failure(check_failed_error, message: /in mock 'unknown': #{signature} expects at least 1 positional arguments but got only 0/, line: __LINE__+1) do
          mock.m(b: 10) { }
        end
      end
  end

  def test_signature_validator_does_accept_both_a_hash_and_a_proc_as_positional_arguments
      FlexMock.use do |mock|
        mock.should_receive(:m).with_signature(required_arguments: 3)
        mock.m(10, Hash[b: 10], proc {})
      end
  end

  def test_signature_validator_does_not_accept_a_lone_hash_as_positional_argument_if_there_are_required_keyword_arguments
      FlexMock.use do |mock|
        mock.should_receive(:m).
          with_signature(required_keyword_arguments: [:b], required_arguments: 1)
        signature = 'm\(\*args, \*\*kwargs\)'
        if RUBY_VERSION < "3"
          signature = 'm\(\*args\)'
          assert_mock_failure(check_failed_error, message: /in mock 'unknown': #{signature} expects at least 1 positional arguments but got only 0/, line: __LINE__+1) do
            mock.m({ :foo => "bar" })
          end
        end
        assert_mock_failure(check_failed_error, message: /in mock 'unknown': #{signature} expects at least 1 positional arguments but got only 0/, line: __LINE__+1) do
          mock.m(b: 10)
        end
      end
  end

  def test_with_signature_matching_sets_up_the_signature_predicate_based_on_the_provided_instance_method_positional_arguments
    k = Class.new { def m(req_a, req_b, opt_c = 10); end }
    FlexMock.use do |mock|
      e = mock.should_receive(:m).with_signature_matching(k.instance_method(:m))
      e = e.instance_variable_get(:@expectations).first
      validator = e.instance_variable_get(:@signature_validator)
      assert_equal 2, validator.required_arguments
      assert_equal 1, validator.optional_arguments
      refute validator.splat?
      assert_equal Set.new, validator.required_keyword_arguments
      assert_equal Set.new, validator.optional_keyword_arguments
      assert_equal false, validator.keyword_splat?
    end
  end

  def test_with_signature_matching_sets_up_the_signature_predicate_based_on_the_provided_instance_method_splat
    k = Class.new { def m(req_a, req_b, opt_c = 10, *splat); end }
    FlexMock.use do |mock|
      e = mock.should_receive(:m).with_signature_matching(k.instance_method(:m))
      e = e.instance_variable_get(:@expectations).first
      validator = e.instance_variable_get(:@signature_validator)
      assert_equal 2, validator.required_arguments
      assert_equal 1, validator.optional_arguments
      assert validator.splat?
      assert_equal Set.new, validator.required_keyword_arguments
      assert_equal Set.new, validator.optional_keyword_arguments
      assert_equal false, validator.keyword_splat?
    end
  end

  def test_signature_validator_from_instance_method_raises_if_the_method_description_contains_an_unknown_argument_type
    mock = flexmock(parameters: [[:unknown]])
    error = assert_raises(ArgumentError) do
      FlexMock::SignatureValidator.from_instance_method(flexmock, mock)
    end
    assert_equal "cannot interpret parameter type unknown", error.message
  end

  def test_private_Object_methods_can_be_mocked
    FlexMock.use do |m|
      m.should_receive(:warn).returns(1)
      assert_equal 1, m.warn
      assert_equal 1, m.send(:warn)
    end
  end

  private

  def assert_operator(op, &block)
    m = flexmock("mock")
    m.should_receive(op).and_return(:value)
    assert_equal :value, block.call(m)
  end

end

class TestFlexMockShouldsWithInclude < Minitest::Test
  include FlexMock::ArgumentTypes
  def test_include_enables_unqualified_arg_type_references
    FlexMock.use("x") do |m|
      m.should_receive(:hi).with(any).once
      m.hi(1)
    end
  end
end

class TestFlexMockArgTypesDontLeak < Minitest::Test
  def test_unqualified_arg_type_references_are_undefined_by_default
    ex = assert_raises(NameError) do
      FlexMock.use("x") do |m|
        m.should_receive(:hi).with(any).once
        m.hi(1)
      end
    end
    assert_match(/\bany\b/, ex.message, "Error message should mention 'any'")
  end
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.1')
    require_relative 'should_receive_ruby21plus'
end
