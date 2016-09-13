#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'flexmock/noop'
require 'flexmock/expectation_builder'

class FlexMock

  # PartialMockProxy is used to mate the mock framework to an existing
  # object. The object is "enhanced" with a reference to a mock object
  # (stored in <tt>@flexmock_proxy</tt>). When the +should_receive+
  # method is sent to the proxy, it overrides the existing object's
  # method by creating singleton method that forwards to the mock.
  # When testing is complete, PartialMockProxy will erase the mocking
  # infrastructure from the object being mocked (e.g. remove instance
  # variables and mock singleton methods).
  #
  class PartialMockProxy
    include Ordering

    attr_reader :mock

    ProxyBox = Struct.new :proxy

    # Make a partial mock proxy and install it on the target +obj+.
    def self.make_proxy_for(obj, container, name, safe_mode)
      name ||= "flexmock(#{obj.class.to_s})"
      if ! proxy_defined_on?(obj)
        mock = FlexMock.new(name, container)
        proxy = PartialMockProxy.new(obj, mock, safe_mode)
        if obj.instance_variable_defined?("@flexmock_proxy")
          obj.instance_variable_get("@flexmock_proxy").proxy = proxy
        else
          obj.instance_variable_set("@flexmock_proxy", ProxyBox.new(proxy))
        end
      end
      obj.instance_variable_get("@flexmock_proxy").proxy
    end

    # Is there a mock proxy defined on the domain object?
    def self.proxy_defined_on?(obj)
      obj.instance_variable_defined?("@flexmock_proxy") &&
        obj.instance_variable_get("@flexmock_proxy").proxy
    end

    # The following methods are added to partial mocks so that they
    # can act like a mock.

    MOCK_METHODS = [
      :should_receive, :new_instances,
      :should_receive_with_location,
      :flexmock_get,   :flexmock_teardown, :flexmock_verify,
      :flexmock_received?, :flexmock_calls, :flexmock_find_expectation
    ]

    # Initialize a PartialMockProxy object.
    def initialize(obj, mock, safe_mode)
      @obj = obj
      @mock = mock
      @method_definitions = {}
      @methods_proxied = []
      @proxy_definition_module = nil
      @initialize_override = nil
      unless safe_mode
        add_mock_method(:should_receive)
        MOCK_METHODS.each do |sym|
          unless @obj.respond_to?(sym)
            add_mock_method(sym)
          end
        end
      end
    end

    # Get the mock object for the partial mock.
    def flexmock_get
      @mock
    end

    # :call-seq:
    #    should_receive(:method_name)
    #    should_receive(:method1, method2, ...)
    #    should_receive(:meth1 => result1, :meth2 => result2, ...)
    #
    # Declare that the partial mock should receive a message with the given
    # name.
    #
    # If more than one method name is given, then the mock object should
    # expect to receive all the listed melthods.  If a hash of method
    # name/value pairs is given, then the each method will return the
    # associated result.  Any expectations applied to the result of
    # +should_receive+ will be applied to all the methods defined in the
    # argument list.
    #
    # An expectation object for the method name is returned as the result of
    # this method.  Further expectation constraints can be added by chaining
    # to the result.
    #
    # See Expectation for a list of declarators that can be used.
    def should_receive(*args)
      flexmock_define_expectation(caller, *args)
    end

    def flexmock_define_expectation(location, *args)
      EXP_BUILDER.parse_should_args(self, args) do |method_name|
        if !@methods_proxied.include?(method_name)
          hide_existing_method(method_name)
        end
        ex = @mock.flexmock_define_expectation(location, method_name)
        if FlexMock.partials_verify_signatures
          if existing_method = @method_definitions[method_name]
            ex.with_signature_matching(existing_method)
          end
        end
        ex.mock = self
        ex
      end
    end

    def flexmock_find_expectation(*args)
      @mock.flexmock_find_expectation(*args)
    end

    def add_mock_method(method_name)
      stow_existing_definition(method_name)
      proxy_module_eval do
        define_method(method_name) { |*args, &block|
          proxy = __flexmock_proxy or
            fail "Missing FlexMock proxy " +
                 "(for method_name=#{method_name.inspect}, self=\#{self})"
          proxy.send(method_name, *args, &block)
        }
      end
    end

    # :call-seq:
    #   new_instances.should_receive(...)
    #   new_instances { |instance|  instance.should_receive(...) }
    #
    # new_instances is a short cut method for overriding the behavior of any
    # new instances created via a mocked class object.
    #
    # By default, new_instances will mock the behaviour of the :new
    # method.  If you wish to mock a different set of class methods,
    # just pass a list of symbols to as arguments.  (previous versions
    # also mocked :allocate by default.  If you need :allocate to be
    # mocked, just request it explicitly).
    #
    # For example, to stub only objects created by :make (and not
    # :new), use:
    #
    #    flexmock(ClassName).new_instances(:make).should_receive(...)
    #
    def new_instances(*allocators, &block)
      fail ArgumentError, "new_instances requires a Class to stub" unless
        Class === @obj
      location = caller
      allocators = [:initialize] if allocators.empty?

      expectation_recorder = ExpectationRecorder.new

      if allocators.delete(:initialize)
        initialize_stub(expectation_recorder, block)
      end

      allocators.each do |allocate_method|
        flexmock_define_expectation(location, allocate_method).and_return { |*args|
          create_new_mocked_object(
            allocate_method, args, expectation_recorder, block)
        }
      end
      expectation_recorder
    end

    # Stubs the #initialize method on a class
    def initialize_stub(recorder, expectations_block)
      if !@initialize_override
        expectation_blocks    = @initialize_expectation_blocks = Array.new
        expectation_recorders = @initialize_expectation_recorders = Array.new
        @initialize_override = Module.new do
          define_method :initialize do |*args, &block|
            if self.class.respond_to?(:__flexmock_proxy) && (mock = self.class.__flexmock_proxy)
              container = mock.flexmock_container
              mock = container.flexmock(self)
              expectation_blocks.each do |b|
                b.call(mock)
              end
              expectation_recorders.each do |r|
                r.apply(mock)
              end
            end
            super(*args, &block)
          end
        end
        override = @initialize_override
        @obj.class_eval { prepend override }
      end
      if expectations_block
        @initialize_expectation_blocks    << expectations_block
      end
      @initialize_expectation_recorders << recorder
    end

    def initialize_stub?
      !!@initialize_override
    end

    def initialize_stub_remove
      if initialize_stub?
        @initialize_expectation_blocks.clear
        @initialize_expectation_recorders.clear
      end
    end

    # Create a new mocked object.
    #
    # The mocked object is created using the following steps:
    # (1) Allocate with the original allocation method (and args)
    # (2) Pass to the block for custom configuration.
    # (3) Apply any recorded expecations
    #
    def create_new_mocked_object(allocate_method, args, recorder, block)
      new_obj = flexmock_invoke_original(allocate_method, args)
      mock = flexmock_container.flexmock(new_obj)
      block.call(mock) unless block.nil?
      recorder.apply(mock)
      new_obj
    end
    private :create_new_mocked_object

    # Invoke the original definition of method on the object supported by
    # the stub.
    def flexmock_invoke_original(method, args)
      if original_method = @method_definitions[method]
        if Proc === args.last
          block = args.last
          args = args[0..-2]
        end
        original_method.bind(@obj).call(*args, &block)
      else
        @obj.__send__(:method_missing, method, *args, &block)
      end
    end

    # Verify that the mock has been properly called.  After verification,
    # detach the mocking infrastructure from the existing object.
    def flexmock_verify
      @mock.flexmock_verify
    end

    # Remove all traces of the mocking framework from the existing object.
    def flexmock_teardown
      if ! detached?
        initialize_stub_remove
        proxy_module_eval do
          methods = instance_methods(false).to_a
          methods.each do |m|
            remove_method m
          end
        end
        if @obj.instance_variable_defined?(:@flexmock_proxy) &&
            (box = @obj.instance_variable_get(:@flexmock_proxy))
          box.proxy = nil
        end
        @obj = nil
      end
    end

    # Forward to the mock's container.
    def flexmock_container
      @mock.flexmock_container
    end

    # Forward to the mock
    def flexmock_received?(*args)
      @mock.flexmock_received?(*args)
    end

    # Forward to the mock
    def flexmock_calls
      @mock.flexmock_calls
    end

    # Set the proxy's mock container.  This set value is ignored
    # because the proxy always uses the container of its mock.
    def flexmock_container=(container)
    end

    # Forward the request for the expectation director to the mock.
    def flexmock_expectations_for(method_name)
      @mock.flexmock_expectations_for(method_name)
    end

    # Forward the based on request.
    def flexmock_based_on(*args)
      @mock.flexmock_based_on(*args)
    end

    private

    # The singleton class of the object.
    def target_singleton_class
      @obj.singleton_class
    end

    # Evaluate a block (or string) in the context of the singleton
    # class of the target partial object.
    def target_class_eval(*args, &block)
      target_singleton_class.class_eval(*args, &block)
    end

    # Evaluate a block into the module we use to define the proxy methods
    def proxy_module_eval(*args, &block)
      if !@proxy_definition_module
        obj = @obj
        @proxy_definition_module = m = Module.new do
          define_method("__flexmock_proxy") do
            if box = obj.instance_variable_get(:@flexmock_proxy)
              box.proxy
            end
          end
        end
        target_class_eval { prepend m }
      end
      @proxy_definition_module.class_eval(*args, &block)
    end

    # Hide the existing method definition with a singleton defintion
    # that proxies to our mock object.  If the current definition is a
    # singleton, we need to record the definition and remove it before
    # creating our own singleton method.  If the current definition is
    # not a singleton, all we need to do is override it with our own
    # singleton.
    def hide_existing_method(method_name)
      existing_method = stow_existing_definition(method_name)
      define_proxy_method(method_name)
      existing_method
    end

    # Stow the existing method definition so that it can be recovered
    # later.
    def stow_existing_definition(method_name)
      if !@methods_proxied.include?(method_name)
        @method_definitions[method_name] = target_class_eval { instance_method(method_name) }
        @methods_proxied << method_name
      end
      @method_definitions[method_name]
    rescue NameError
    end

    # Define a proxy method that forwards to our mock object.  The
    # proxy method is defined as a singleton method on the object
    # being mocked.
    def define_proxy_method(method_name)
      if method_name =~ /=$/
        proxy_module_eval do
          define_method(method_name) do |*args, &block|
            __flexmock_proxy.mock.__send__(method_name, *args, &block)
          end
        end
      else
        proxy_module_eval <<-EOD
          def #{method_name}(*args, &block)
            FlexMock.verify_mocking_allowed!
            __flexmock_proxy.mock.#{method_name}(*args, &block)
          end
        EOD
      end
    end

    # Have we been detached from the existing object?
    def detached?
      @obj.nil?
    end

  end
end
