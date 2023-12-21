#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'test_helper'

class TestStubbing < Minitest::Test
  include FlexMock::Minitest

  class Dog
    def bark
      :woof
    end
    def Dog.create
      :new_dog
    end
  end

  class DogPlus < Dog
    def should_receive
      :dog_should
    end
    def new_instances
      :dog_new
    end
    def by_default
      :dog_by_default
    end
  end

  def test_attempting_to_partially_mock_existing_mock_is_noop
    m = flexmock("A")
    flexmock(m)
    assert ! m.instance_variables.include?(:@flexmock_proxy.flexmock_as_name)
  end

  def test_forcibly_removing_proxy_causes_failure
    obj = Object.new
    flexmock(obj)
    obj.instance_eval { @flexmock_proxy = nil }
    ex = assert_raises(RuntimeError) do
      obj.should_receive(:hi).and_return(:stub_hi)
    end
    assert(ex.message =~ /missing.*proxy/i)
  end

  def test_stub_command_add_behavior_to_arbitrary_objects_via_flexmock
    obj = Object.new
    flexmock(obj).should_receive(:hi).and_return(:stub_hi)
    assert_equal :stub_hi, obj.hi
  end

  def test_stub_command_add_behavior_to_arbitrary_objects_post_flexmock
    obj = Object.new
    flexmock(obj)
    obj.should_receive(:hi).and_return(:stub_hi)
    assert_equal :stub_hi, obj.hi
  end

  def test_stub_command_can_configure_via_block
    obj = Object.new
    flexmock(obj) do |m|
      m.should_receive(:hi).once.and_return(:stub_hi)
    end
    assert_equal :stub_hi, obj.hi
  end

  def test_stubbed_methods_can_take_blocks
    obj = Object.new
    flexmock(obj).should_receive(:with_block).once.with(Proc).
      and_return { |block| block.call }
    assert_equal :block, obj.with_block { :block }
  end

  def test_multiple_stubs_on_the_same_object_reuse_the_same_partial_mock
    obj = Object.new
    a = flexmock(obj)
    b = flexmock(obj)
    assert_equal a.object_id, b.object_id
  end

  def test_stubbed_methods_can_invoke_original_behavior_directly
    dog = Dog.new
    flexmock(dog).should_receive(:bark).pass_thru.once
    assert_equal :woof, dog.bark
  end

  def test_stubbed_methods_handle_singleton_methods_added_after_the_mock_was_created
    dog = Dog.new
    m = Module.new do
      def bark
        :baaaaaark
      end
    end
    flexmock(dog).should_receive(:bark).pass_thru.once
    dog.extend m
    assert_equal :baaaaaark, dog.bark
  end

  def test_invoke_original_allows_to_call_the_original_directly
    dog = Dog.new
    flexmock(dog).should_receive(:bark).never
    assert_equal :woof, dog.invoke_original(:bark)
  end

  def test_invoke_original_can_pass_a_block
    dog = Class.new do
      def bark(&block)
        block.call
      end
    end.new
    recorder = flexmock.should_receive(:called).once.mock
    flexmock(dog).should_receive(:bark).never
    dog.invoke_original(:bark) { recorder.called }
  end

  def test_stubbed_methods_can_invoke_original_behavior_with_modification
    dog = Dog.new
    flexmock(dog).should_receive(:bark).pass_thru { |result| result.to_s.upcase }.once
    assert_equal "WOOF", dog.bark
  end

  def test_stubbed_methods_returning_partial_mocks
    flexmock(Dog).should_receive(:new).pass_thru { |dog|
      flexmock(dog, :beg => "Please")
    }.once
    dog = Dog.new
    assert_equal "Please", dog.beg
    assert_equal :woof, dog.bark
  end

  def test_multiple_methods_can_be_stubbed
    dog = Dog.new
    flexmock(dog).should_receive(:bark).and_return(:grrrr)
    flexmock(dog).should_receive(:wag).and_return(:happy)
    assert_equal :grrrr, dog.bark
    assert_equal :happy, dog.wag
  end

  def test_original_behavior_can_be_restored
    dog = Dog.new
    partial_mock = flexmock(dog)
    partial_mock.should_receive(:bark).once.and_return(:growl)
    assert_equal :growl, dog.bark
    partial_mock.flexmock_teardown
    assert_equal :woof, dog.bark
    assert_nil dog.instance_variable_get("@flexmock_proxy").proxy
  end

  def test_original_missing_behavior_can_be_restored
    obj = Object.new
    partial_mock = flexmock(obj)
    partial_mock.should_receive(:hi).once.and_return(:ok)
    assert_equal :ok, obj.hi
    partial_mock.flexmock_teardown
    assert_raises(NoMethodError) { obj.hi }
  end

  def test_multiple_stubs_on_single_method_can_be_restored_missing_method
    obj = Object.new
    partial_mock = flexmock(obj)
    partial_mock.should_receive(:hi).with(1).once.and_return(:ok)
    partial_mock.should_receive(:hi).with(2).once.and_return(:ok)
    assert_equal :ok, obj.hi(1)
    assert_equal :ok, obj.hi(2)
    partial_mock.flexmock_teardown
    assert_raises(NoMethodError) { obj.hi }
  end

  def test_original_behavior_is_restored_when_multiple_methods_are_mocked
    dog = Dog.new
    flexmock(dog).should_receive(:bark).and_return(:grrrr)
    flexmock(dog).should_receive(:wag).and_return(:happy)
    flexmock(dog).flexmock_teardown
    assert_equal :woof, dog.bark
    assert_raises(NoMethodError) { dog.wag }
  end

  def test_original_behavior_is_restored_on_class_objects
    flexmock(Dog).should_receive(:create).once.and_return(:new_stub)
    assert_equal :new_stub, Dog.create
    flexmock(Dog).flexmock_teardown
    assert_equal :new_dog, Dog.create
  end

  def test_original_behavior_is_restored_on_singleton_methods
    obj = Object.new
    def obj.hi() :hello end
    flexmock(obj).should_receive(:hi).once.and_return(:hola)

    assert_equal :hola, obj.hi
    flexmock(obj).flexmock_teardown
    assert_equal :hello, obj.hi
  end

  def test_original_behavior_is_restored_on_singleton_methods_with_multiple_stubs
    obj = Object.new
    def obj.hi(n) "hello#{n}" end
    flexmock(obj).should_receive(:hi).with(1).once.and_return(:hola)
    flexmock(obj).should_receive(:hi).with(2).once.and_return(:hola)

    assert_equal :hola, obj.hi(1)
    assert_equal :hola, obj.hi(2)
    flexmock(obj).flexmock_teardown
    assert_equal "hello3", obj.hi(3)
  end

  def test_original_behavior_is_restored_on_nonsingleton_methods_with_multiple_stubs
    flexmock(Dir).should_receive(:chdir).with("xx").once.and_return(:ok1)
    flexmock(Dir).should_receive(:chdir).with("yy").once.and_return(:ok2)
    assert_equal :ok1, Dir.chdir("xx")
    assert_equal :ok2, Dir.chdir("yy")

    flexmock(Dir).flexmock_teardown

    x = :not_called
    Dir.chdir("test") do
      assert_match %r{/test$}, Dir.pwd
      x = :called
    end
    assert_equal :called, x
  end

  def test_stubbing_file_shouldnt_break_writing
    flexmock(File).should_receive(:open).with("foo").once.and_return(:ok)
    assert_equal :ok, File.open("foo")
    flexmock(File).flexmock_teardown

    File.open("dummy.txt", "w") do |out|
      assert out.is_a?(IO)
      out.puts "XYZ"
    end
    text = File.open("dummy.txt") { |f| f.read }
    assert_equal "XYZ\n", text
  ensure
    FileUtils.rm_f("dummy.txt")
  end

  def test_original_behavior_is_restored_even_when_errors
    flexmock(Dog).should_receive(:create).once.and_return(:mock)
    begin
      flexmock_teardown
    rescue assertion_failed_error => _
      nil
    end
    assert_equal :new_dog, Dog.create

    # Now disable the mock so that it doesn't cause errors on normal
    # test teardown
    m = flexmock(Dog).flexmock_get
    def m.flexmock_verify() end
  end

  def test_not_calling_stubbed_method_is_an_error
    dog = Dog.new
    flexmock(dog).should_receive(:bark).once
    assert_raises(assertion_failed_error) {
      flexmock(dog).flexmock_verify
    }
    dog.bark
  end

  def test_mock_is_verified_when_the_stub_is_verified
    obj = Object.new
    partial_mock = flexmock(obj)
    partial_mock.should_receive(:hi).once.and_return(:ok)
    assert_raises(assertion_failed_error) {
      partial_mock.flexmock_verify
    }
  end

  def test_stub_can_have_explicit_name
    obj = Object.new
    partial_mock = flexmock(obj, "Charlie")
    assert_equal "Charlie", partial_mock.flexmock_get.flexmock_name
  end

  def test_unamed_stub_will_use_default_naming_convention
    obj = Object.new
    partial_mock = flexmock(obj)
    assert_equal "flexmock(Object)", partial_mock.flexmock_get.flexmock_name
  end

  def test_partials_can_be_defined_in_a_block
    dog = Dog.new
    flexmock(dog) do |m|
      m.should_receive(:bark).and_return(:growl)
    end
    assert_equal :growl, dog.bark
  end

  def test_partials_defining_block_return_real_obj_not_proxy
    dog = flexmock(Dog.new) do |m|
      m.should_receive(:bark).and_return(:growl)
    end
    assert_equal :growl, dog.bark
  end

  def test_partial_mocks_always_return_domain_object
    dog = Dog.new
    assert_equal dog, flexmock(dog)
    assert_equal dog, flexmock(dog) { }
  end

  MOCK_METHOD_SUBSET = [
    :should_receive, :new_instances,
    :flexmock_get,   :flexmock_teardown, :flexmock_verify,
  ]

  def test_domain_objects_do_not_have_mock_methods
    dog = Dog.new
    MOCK_METHOD_SUBSET.each do |sym|
      assert ! dog.respond_to?(sym), "should not have :#{sym} defined"
    end
  end

  def test_partial_mocks_have_mock_methods
    dog = Dog.new
    flexmock(dog)
    MOCK_METHOD_SUBSET.each do |sym|
      assert dog.respond_to?(sym), "should have :#{sym} defined"
    end
  end

  def test_partial_mocks_do_not_have_mock_methods_after_teardown
    dog = Dog.new
    flexmock(dog)
    dog.flexmock_teardown
    MOCK_METHOD_SUBSET.each do |sym|
      assert ! dog.respond_to?(sym), "should not have :#{sym} defined"
    end
  end

  # This test ensures that singleton? does not use the old methods(false)
  # call that has fallen out of favor in Ruby 1.9. In multiple 1.9 releases
  # Delegator#methods will not even accept the optional argument, making flexmock
  # explode. Since there is a way to get singleton methods officially we might
  # as well just do it, right?
  class NoMethods
    def methods(arg = true)
      raise "Should not be called in the test lifecycle"
    end
  end

  def xtest_object_methods_method_is_not_used_in_singleton_checks
    obj = NoMethods.new
    def obj.mock() :original end
    flexmock(obj)
  end

  def test_partial_mocks_with_mock_method_singleton_colision_have_original_defs_restored
    dog = Dog.new
    def dog.mock() :original end
    flexmock(dog)
    dog.flexmock_teardown
    assert_equal :original, dog.mock
  end

  class MockColision
    def mock
      :original
    end
  end

  def test_partial_mocks_with_mock_method_non_singleton_colision_have_original_defs_restored
    mc = MockColision.new
    flexmock(mc)
    mc.flexmock_teardown
    assert_equal :original, mc.mock
  end

  def test_safe_partial_mocks_do_not_support_mock_methods
    dog = Dog.new
    flexmock(:safe, dog) { }
    MOCK_METHOD_SUBSET.each do |sym|
      assert ! dog.respond_to?(sym), "should not have :#{sym} defined"
    end
  end

  def test_safe_partial_mocks_require_block
    dog = Dog.new
    assert_raises(FlexMock::UsageError) { flexmock(:safe, dog) }
  end

  def test_safe_partial_mocks_are_actually_mocked
    dog = flexmock(:safe, Dog.new) { |m| m.should_receive(:bark => :mocked) }
    assert_equal :mocked, dog.bark
  end

  def test_should_receive_does_not_override_preexisting_def
    dog = flexmock(DogPlus.new)
    assert_equal :dog_new,        dog.new_instances
    assert_equal :dog_by_default, dog.by_default
  end

  def test_should_receive_does_override_should_receive_preexisting_def
    dog = flexmock(DogPlus.new)
    assert_kind_of FlexMock::CompositeExpectation, dog.should_receive(:x)
  end

  class Liar
    def respond_to?(method_name)
      sym = method_name.to_sym
      if sym == :not_defined
        true
      else
        super(method_name)
      end
    end
  end

  def test_liar_actually_lies
    liar = Liar.new
    assert liar.respond_to?(:not_defined)
    assert_raises(NoMethodError) { liar.not_defined }
  end

  def test_partial_mock_where_respond_to_is_true_yet_method_is_not_there
    liar = Liar.new
    flexmock(liar, :not_defined => :xyzzy)
    assert_equal :xyzzy, liar.not_defined
  end

  class MetaDog < Dog
    def method_missing(method, *args, &block)
      if method.to_s =~ /meow/
        :meow
      else
        super
      end
    end
    def respond_to_missing?(method, *)
      method =~ /meow/ || super
    end
  end

  def test_partial_mock_where_method_created_by_method_missing_and_respond_to_missing
    dog = MetaDog.new
    flexmock(dog, :meow => :hiss)
    assert_equal :hiss, dog.meow
  end

  def test_partial_mocks_allow_stubbing_defined_methods_when_using_on
    dog = Dog.new
    flexmock(dog, :on, Dog)
    dog.should_receive(:bark).and_return(:grrr)
    assert_equal :grrr, dog.bark
  end

  def test_partial_mocks_disallow_stubbing_undefined_methods_when_using_on
    dog = Dog.new
    flexmock(dog, :on, Dog)
    assert_raises(NoMethodError, /meow.*explicitly/) do
      dog.should_receive(:meow).and_return(:something)
    end
  end

  def test_partial_mocks_properly_detect_methods_defined_through_a_class_hierarchy
    dog = Class.new do
      class << self
        def bark
        end
      end
    end
    chiwawa = Class.new(dog)

    FlexMock.partials_are_based = true
    flexmock(chiwawa)
    chiwawa.should_receive(:bark).and_return(:grrr)
    assert_equal :grrr, chiwawa.bark
  ensure
    FlexMock.partials_are_based = false
  end

  if FlexMock::ON_RUBY_20
    # This is a limitation due to 2.0's broken #ancestors on singletons of classes
    def test_partial_mocks_will_not_require_explicitly_on_a_class_singleton_method_that_has_been_mocked_on_the_parent_class
      dog = Class.new
      chiwawa = Class.new(dog)

      FlexMock.partials_are_based = true
      flexmock(dog).should_receive(:bark).explicitly
      flexmock(chiwawa)
      chiwawa.should_receive(:bark).and_return(:grrr)
      assert_equal :grrr, chiwawa.bark
    ensure
      FlexMock.partials_are_based = false
    end
  else
    def test_based_partial_mocks_require_explicitly_on_a_non_existing_method_of_a_class_singleton
      dog = Class.new
      FlexMock.partials_are_based = true
      assert_raises(NoMethodError, /bark.*explicitly/) do
        flexmock(dog).should_receive(:bark).and_return(:grrr)
      end
    ensure
      FlexMock.partials_are_based = false
    end

    def test_partial_mocks_require_explicitly_on_a_class_singleton_method_that_has_been_mocked_on_the_parent_class
      dog = Class.new
      chiwawa = Class.new(dog)

      FlexMock.partials_are_based = true
      flexmock(dog).should_receive(:bark).explicitly
      flexmock(chiwawa)
      assert_raises(NoMethodError, /bark.*explicitly/) do
        chiwawa.should_receive(:bark).and_return(:grrr)
      end
    ensure
      FlexMock.partials_are_based = false
    end
  end

  def test_partial_mocks_do_not_stow_their_own_method_definitions
    dog = Dog.new
    flexmock(dog)
    dog.should_receive(:meow).explicitly.and_return(:something)
    dog.should_receive(:meow).explicitly.and_return(:something_else)
    refute dog.__flexmock_proxy.has_original_method?(:meow)
  end

  def test_partial_mocks_allow_explicitely_stubbing_methods_in_sequence_when_signature_verification_is_on
    dog = Dog.new
    flexmock(dog, :on, Dog)
    FlexMock.partials_verify_signatures = true
    dog.should_receive(:meow).explicitly.and_return(:something)
    dog.should_receive(:meow).explicitly.and_return(:something_else)
  ensure
    FlexMock.partials_verify_signatures = false
  end

  # The following test was suggested by Pat Maddox for the RSpec
  # mocks.  Evidently the (poorly implemented) == method caused issues
  # with RSpec Mock's internals.  I'm just double checking for any
  # similar issues in FlexMock as well.

  class ValueObject
    attr_reader :val

    def initialize(val)
      @val = val
    end

    def ==(other)
      @val == other.val
    end
  end

  def test_partial_mocks_in_the_presense_of_equal_definition
    flexmock("existing obj", :foo => :foo)
    obj = ValueObject.new(:bar)
    flexmock(obj, :some_method => :some_method)
  end

  def test_partial_mocks_can_stub_methods_already_prepended_on_the_singleton_class
    m = Module.new { def foo; 10 end }
    obj = Class.new.new
    obj.singleton_class.class_eval { prepend m }
    flexmock(obj).should_receive(:foo).once.and_return(20)
    assert_equal 20, obj.foo
  end

  def test_partial_mocks_can_call_original_methods_already_prepended_on_the_singleton_class
    m = Module.new { def foo; 10 end }
    obj = Class.new.new
    obj.singleton_class.class_eval { prepend m }
    flexmock(obj).should_receive(:foo).once.pass_thru { |val| val * 3 }
    assert_equal 30, obj.foo
  end

  def test_partial_mocks_can_call_an_original_message_that_is_handled_by_method_missing
    obj = Class.new do
      attr_reader :mm_calls
      def initialize
        @mm_calls = Array.new
      end
      def method_missing(m, *args, &block)
        @mm_calls << [m, args, block]
        if m == :mm_handled_message
          args[0] * 10 + args[1]
        else
          super
        end
      end
    end.new
    flexmock(obj).should_receive(:mm_handled_message).with(10, 20).once.pass_thru
    assert_equal 120, obj.mm_handled_message(10, 20)
    assert_equal [[:mm_handled_message, [10, 20], nil]], obj.mm_calls
  end

  def test_partial_mocks_mentions_the_pass_thru_clause_when_passing_thru_to_a_non_handled_message
    obj = Class.new do
      attr_reader :mm_calls
      def initialize
        @mm_calls = Array.new
      end
      def method_missing(m, *args, &block)
        @mm_calls << [m, args, block]
        super
      end
    end.new
    flexmock(obj).should_receive(:does_not_exist).with(10, 20).once.pass_thru
    exception = assert_raises(NoMethodError) do
        obj.does_not_exist(10, 20)
    end
    assert(/pass_thru/ === exception.message, "expected #{exception.message} to mention the flexmock pass_thru clause")
  end

  def test_partial_mocks_leaves_exceptions_raised_by_the_original_method_unchanged
    error_m = Class.new(RuntimeError)
    obj = Class.new do
      define_method(:mocked_method) { raise error_m, "the error message" }
    end.new
    flexmock(obj).should_receive(:mocked_method).pass_thru
    exception = assert_raises(error_m) do
        obj.mocked_method
    end
    assert_equal "the error message", exception.message
  end

  def test_partial_mocks_leaves_NoMethodError_exceptions_raised_by_the_original_method_unchanged
    obj = Class.new do
      define_method(:mocked_method) { does_not_exist() }
    end.new
    flexmock(obj).should_receive(:mocked_method).pass_thru
    exception = assert_raises(NameError) do
        obj.mocked_method
    end
    assert_match /undefined method `does_not_exist' for/, exception.message
  end

  def test_it_checks_whether_mocks_are_forbidden_before_forwarding_the_call
      obj = Class.new
      flexmock(obj).should_receive(:mocked).never
      result = FlexMock.forbid_mocking(tag = Object.new) do
        obj.mocked
      end
      assert_same result, tag
  end

  def test_inspect_on_mocked_method_can_successfully_call_a_mocked_method
      obj = Class.new do
          def inspect
              mocked(self)
          end
      end.new
      flexmock(obj).should_receive(:mocked).with(any).and_return("10")
      obj.inspect
  end

  def test_inspect_on_mocked_method_can_fail_at_calling_a_mocked_method
      obj = Class.new do
          def inspect
              mocked(self)
          end
      end.new
      flexmock(obj).should_receive(:mocked).never
      assert_raises(FlexMock::CheckFailedError) do
        obj.inspect
      end
  end

  def test_the_strict_keyword_raises_if_used_on_a_non_partial_mock
    error = assert_raises(ArgumentError) do
      flexmock('name', :strict)
    end
    assert_equal "cannot use :strict outside a partial mock", error.message
  end

  def test_the_strict_keyword_sets_the_base_class_to_the_partial_mock_singleton_class
    klass = Class.new
    m = Module.new
    obj = klass.new
    obj.extend m
    mock = flexmock(obj, :strict)
    assert_equal obj.singleton_class, mock.flexmock_get.flexmock_base_class
  end

  def test_it_verifies_the_signature_against_the_original_method_if_partials_verify_signatures_is_set
    FlexMock.partials_verify_signatures = true
    k = Class.new do
      def m(a); end
    end
    flexmock(obj = k.new).should_receive(:m)

    assert_mock_failure(check_failed_error, deep: true, message: /expects at least 1 positional arguments but got only 0/, line: __LINE__+1) do
      obj.m
    end
  ensure
    FlexMock.partials_verify_signatures = false
  end

  def test_it_can_setup_mocks_recursively
    obj = Object.new
    FlexMock.use(obj) do
      obj.should_receive(:foo).once
      FlexMock.use(obj) do
        obj.should_receive(:blah).once
        obj.blah
      end
      obj.should_receive(:bar).once
      obj.foo
      obj.bar
    end
  end

  def test_it_passes_calls_from_child_contexts_to_parent_contexts
    obj = Object.new
    FlexMock.use(obj) do
      obj.should_receive(:foo).once
      FlexMock.use(obj) do
        obj.foo
      end
    end
  end

  def test_expectations_defined_in_sub_contexts_are_added_to_the_ones_in_parent_contexts
    obj = Object.new
    FlexMock.use(obj) do
      obj.should_receive(:foo).with(10).once
      FlexMock.use(obj) do
        obj.should_receive(:foo).with(20).once
        obj.foo(10)
        obj.foo(20)
      end
    end
  end

  def test_it_calls_the_true_original_method_in_children_contexts
    obj = Class.new do
      attr_reader :value
      def initialize; @value = 0 end
      def call(value); @value += 1 end
    end.new

    FlexMock.use(obj) do
      obj.should_receive(:call).with(1)
      FlexMock.use(obj) do
        obj.should_receive(:call).with(2).pass_thru
        obj.call(2)
      end
      obj.call(1)
    end
    assert_equal 1, obj.value
  end

  def test_should_expect
    flexmock(obj = Dog.new).should_expect do |e|
      e.bark
    end
    obj.bark
  end

  def test_interaction_between_signature_verification_and_based_partials
    FlexMock.partials_are_based = true
    FlexMock.partials_verify_signatures = true
    obj = flexmock(obj = Dog.new)
    obj.should_receive(:puts).explicitly.once
    obj.puts "test"
  ensure
    FlexMock.partials_are_based = false
    FlexMock.partials_verify_signatures = false
  end
end

