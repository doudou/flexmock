#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'flexmock/errors'
require 'flexmock/ordering'
require 'flexmock/argument_matching'
require 'flexmock/explicit_needed'
require 'flexmock/class_extensions'
require 'flexmock/expectation_builder'
require 'flexmock/call_validator'
require 'flexmock/call_record'

# FlexMock is a flexible mock object framework for creating and using
# test doubles (mocks, stubs and spies).
#
# Basic Usage:
#
#   m = flexmock("name")
#   m.should_receive(:upcase).with("stuff").
#     and_return("STUFF")
#   m.should_receive(:downcase).with(String).
#     and_return { |s| s.downcase }.once
#
# With Test::Unit Integration:
#
#   class TestSomething < Test::Unit::TestCase
#     def test_something
#       m = flexmock("name")
#       m.should_receive(:hi).and_return("Hello")
#       m.hi
#     end
#   end
#
# Note: Also, if you override +teardown+, make sure you call +super+.
#
class FlexMock
  include Ordering

  attr_reader :flexmock_name
  attr_reader :flexmock_container_stack

  class << self
    attr_accessor :partials_are_based
    attr_accessor :partials_verify_signatures
  end
  self.partials_are_based = false
  self.partials_verify_signatures = false

  # Null object for {#parent_mock}
  class NullParentMock
    def flexmock_expectations_for(sym)
    end
  end

  # Create a FlexMock object with the given name.  The name is used in
  # error messages.  If no container is given, create a new, one-off
  # container for this mock.
  def initialize(name="unknown", container=nil, parent: nil)
    @flexmock_name = name
    @flexmock_closed = false
    @flexmock_container_stack = Array.new
    @expectations = Hash.new
    @verified = false
    @calls = []
    @base_class = nil
    if parent
      @ignore_missing = parent.ignore_missing?
      @parent_mock = parent
    else
      @ignore_missing = false
      @parent_mock = NullParentMock.new
    end
    container = UseContainer.new if container.nil?
    container.flexmock_remember(self)
  end

  def ignore_missing?
    @ignore_missing
  end

  def flexmock_container
    flexmock_container_stack.last
  end

  def push_flexmock_container(container)
    flexmock_container_stack.push(container)
  end

  def pop_flexmock_container
    flexmock_container_stack.pop
  end

  # Return the inspection string for a mock.
  def inspect
    "<FlexMock:#{flexmock_name}>"
  end

  # Verify that each method that had an explicit expected count was
  # actually called that many times.
  def flexmock_verify
    return if @verified
    @verified = true
    flexmock_wrap do
      @expectations.each do |sym, handler|
        handler.flexmock_verify
      end
    end
  end

  # Teardown and infrastructure setup for this mock.
  def flexmock_teardown
    @flexmock_closed = true
  end

  def flexmock_closed?
    @flexmock_closed
  end

  # Ignore all undefined (missing) method calls.
  def should_ignore_missing
    @ignore_missing = true
    self
  end
  alias mock_ignore_missing should_ignore_missing

  def by_default
    @last_expectation.by_default
    self
  end

  # Handle missing methods by attempting to look up a handler.
  def method_missing(sym, *args, **kw, &block)
    FlexMock.verify_mocking_allowed!

    enhanced_args = block_given? ? args + [block] : args
    call_record = CallRecord.new(sym, enhanced_args, kw, block_given?)
    @calls << call_record
    flexmock_wrap do
      if flexmock_closed?
        FlexMock.undefined
      elsif exp = flexmock_expectations_for(sym)
        exp.call(enhanced_args, kw, call_record)
      elsif @base_class && @base_class.flexmock_defined?(sym)
        FlexMock.undefined
      elsif @ignore_missing
        FlexMock.undefined
      else
        super(sym, *args, **kw, &block)
      end
    end
  end

  # Save the original definition of respond_to? for use a bit later.
  alias flexmock_respond_to? respond_to?

  # Override the built-in respond_to? to include the mocked methods.
  def respond_to?(sym, *args)
    super || (@expectations[sym] ? true : @ignore_missing)
  end

  # Find the mock expectation for method sym and arguments.
  def flexmock_find_expectation(method_name, *args, **kw) # :nodoc:
    if exp = flexmock_expectations_for(method_name)
      exp.find_expectation(args, kw)
    end
  end

  # Return the expectation director for a method name.
  def flexmock_expectations_for(method_name) # :nodoc:
    @expectations[method_name] || @parent_mock.flexmock_expectations_for(method_name)
  end

  def flexmock_base_class
    @base_class
  end

  def flexmock_based_on(base_class)
    @base_class = base_class
    if base_class <= Kernel
      if self.class != base_class
        should_receive(:class => base_class)
        should_receive(:kind_of?).and_return { |against| base_class <= against }
      end
    end
  end

  CALL_VALIDATOR = CallValidator.new

  # True if the mock received the given method and arguments.
  def flexmock_received?(method_name, args, kw, options = {})
    CALL_VALIDATOR.received?(@calls, method_name, args, kw, options)
  end

  # Return the list of calls made on this mock. Used in formatting
  # error messages.
  def flexmock_calls
    @calls
  end

  # Invocke the original non-mocked functionality for the given
  # symbol.
  def flexmock_invoke_original(method_name, args, kw = {})
    return FlexMock.undefined
  end

  # Override the built-in +method+ to include the mocked methods.
  def method(method_name)
    if (expectations = flexmock_expectations_for(method_name))
      ->(*args, **kw) { expectations.call(args, kw) }
    else
      super
    end
  rescue NameError => ex
    if ignore_missing?
      proc { FlexMock.undefined }
    else
      raise ex
    end
  end

  # :call-seq:
  #    mock.should_receive(:method_name)
  #    mock.should_receive(:method1, method2, ...)
  #    mock.should_receive(:meth1 => result1, :meth2 => result2, ...)
  #
  # Declare that the mock object should receive a message with the given name.
  #
  # If more than one method name is given, then the mock object should expect
  # to receive all the listed melthods.  If a hash of method name/value pairs
  # is given, then the each method will return the associated result.  Any
  # expectations applied to the result of +should_receive+ will be applied to
  # all the methods defined in the argument list.
  #
  # An expectation object for the method name is returned as the result of
  # this method.  Further expectation constraints can be added by chaining to
  # the result.
  #
  # See Expectation for a list of declarators that can be used.
  #
  def should_receive(*args)
    flexmock_define_expectation(caller, *args)
  end

  ON_RUBY_20 = (RUBY_VERSION =~ /^2\.0\./)

  # Using +location+, define the expectations specified by +args+.
  def flexmock_define_expectation(location, *args, **kw)
    @last_expectation = EXP_BUILDER.parse_should_args(self, args, kw) do |method_name|
      exp = flexmock_expectations_for(method_name) || ExpectationDirector.new(method_name)
      @expectations[method_name] = exp
      result = Expectation.new(self, method_name, location)
      exp << result
      override_existing_method(method_name) if flexmock_respond_to?(method_name, true)

      if @base_class && !@base_class.flexmock_defined?(method_name)
        if !ON_RUBY_20 || !@base_class.ancestors.include?(Class)
          result = ExplicitNeeded.new(result, method_name, @base_class)
        end
      end
      result
    end
  end

  # Declare that the mock object should expect methods by providing a
  # recorder for the methods and having the user invoke the expected
  # methods in a block.  Further expectations may be applied the
  # result of the recording call.
  #
  # Example Usage:
  #
  #   mock.should_expect do |record|
  #     record.add(Integer, 4) { |a, b|
  #       a + b
  #     }.at_least.once
  #
  def should_expect
    yield Recorder.new(self)
  end

  private

  # Wrap a block of code so the any assertion errors are wrapped so
  # that the mock name is added to the error message .
  def flexmock_wrap(&block)
    yield
  rescue FlexMock.framework_adapter.assertion_failed_error, FlexMock.framework_adapter.check_failed_error => ex
    raise ex, "in mock '#{@flexmock_name}': #{ex.message}", ex.backtrace
  end

  # Override the existing definition of method +method_name+ in the
  # mock. Most methods depend on the method_missing trick to be
  # invoked. However, if the method already exists, it will not call
  # method_missing. This method defines a singleton method on the mock
  # to explicitly invoke the method_missing logic.
  def override_existing_method(method_name)
    sclass.class_eval <<-EOS
      def #{method_name}(*args, &block)
        method_missing(:#{method_name}, *args, &block)
      end
    EOS
  end

  # Return the singleton class of the mock object.
  def sclass
    class << self; self; end
  end
end

require 'flexmock/core_class_methods'
