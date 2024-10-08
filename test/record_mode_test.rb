#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'test_helper'

class TestRecordMode < Minitest::Test
  include FlexMock::Minitest

  def test_recording_mode_works
    mock = flexmock("mock")
    mock.should_expect do |recorder|
      recorder.f { :answer }
    end
    assert_equal :answer, mock.f
  end

  def test_arguments_are_passed_to_recording_mode_block
    mock = flexmock("mock")
    mock.should_expect do |recorder|
      recorder.f(:arg) do |arg|
        assert_equal :arg, arg
        :answer
      end
    end
    assert_equal :answer, mock.f(:arg)
  end

  def test_recording_mode_handles_multiple_returns
    FlexMock.use("mock") do |mock|
      mock.should_expect do |r|
        answers = [1, 2]
        # HACK: The following lambda is needed in Ruby 1.9 to cause
        # the answers to be properly bound in the following block.
        lambda { }
        r.f { answers.shift }
      end
      assert_equal 1, mock.f
      assert_equal 2, mock.f
    end
  end

  def test_recording_mode_does_not_specify_order
    FlexMock.use("mock") do |mock|
      mock.should_expect do |r|
        r.f { 1 }
        r.g { 2 }
      end
      assert_equal 2, mock.g
      assert_equal 1, mock.f
    end
  end

  def test_recording_mode_gets_block_args_too
    mock = flexmock("mock")
    mock.should_expect do |r|
      r.f(1) { |arg, &block|
        refute_nil block
        block.call
      }
    end

    assert_equal :block_result, mock.f(1) { :block_result }
  end

  def test_recording_mode_should_validate_args_with_equals
    assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+5) do
      FlexMock.use("mock") do |mock|
        mock.should_expect do |r|
          r.f(1)
        end
        mock.f(2)
      end
    end
  end

  def test_recording_mode_should_allow_arg_contraint_validation
    assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+5) do
      FlexMock.use("mock") do |mock|
        mock.should_expect do |r|
          r.f(1)
        end
        mock.f(2)
      end
    end
  end

  def test_recording_mode_should_handle_multiplicity_contraints
    assert_mock_failure(check_failed_error, :line => __LINE__+6) do
      FlexMock.use("mock") do |mock|
        mock.should_expect do |r|
          r.f { :result }.once
        end
        mock.f
        mock.f
      end
    end
  end

  def test_strict_record_mode_requires_exact_argument_matches
    assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+6) do
      FlexMock.use("mock") do |mock|
        mock.should_expect do |rec|
          rec.should_be_strict
          rec.f(Integer)
        end
        mock.f(3)
      end
    end
  end

  def test_strict_record_mode_requires_exact_ordering
    assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+8) do
      FlexMock.use("mock") do |mock|
        mock.should_expect do |rec|
          rec.should_be_strict
          rec.f(1)
          rec.f(2)
        end
        mock.f(2)
        mock.f(1)
      end
    end
  end

  def test_strict_record_mode_requires_once
    assert_mock_failure(check_failed_error, :deep => true, :line => __LINE__+7) do
      FlexMock.use("mock") do |mock|
        mock.should_expect do |rec|
          rec.should_be_strict
          rec.f(1)
        end
        mock.f(1)
        mock.f(1)
      end
    end
  end

  def test_strict_record_mode_can_not_fail
    FlexMock.use("mock") do |mock|
      mock.should_expect do |rec|
        rec.should_be_strict
        rec.f(Integer)
        rec.f(2)
      end
      mock.f(Integer)
      mock.f(2)
    end
  end

end
