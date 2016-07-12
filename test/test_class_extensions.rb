require 'test_helper'

class ClassExtensionsTest < Minitest::Test

  class Dog
    def wag
    end

    def method_missing(sym, *args, &block)
      if sym == :bark
        :woof
      else
        super
      end
    end

    def responds_to?(sym)
      sym == :bark || super
    end
  end

  def test_class_directly_defines_method
    assert Dog.flexmock_defined?(:wag)
  end

  def test_class_indirectly_defines_method
    assert ! Dog.flexmock_defined?(:bark)
  end

  def test_class_does_not_define_method
    assert ! Dog.flexmock_defined?(:jump)
  end

  def test_singleton_class_directly_defines_method
    obj = Dog.new
    obj.singleton_class.class_eval do
        define_method(:jump) { }
    end
    assert obj.singleton_class.flexmock_defined?(:jump)
  end

  def test_flexmock_defined_the_method_through_a_partial_mock
    obj = Dog.new
    FlexMock.use(obj) do |mock|
      mock.should_receive(:jump)
      assert obj.singleton_class.method_defined?(:jump)
      assert !obj.singleton_class.flexmock_defined?(:jump)
    end
  end

  def test_flexmock_defined_works_with_included_modules
    assert Dog.flexmock_defined?(:sleep)
  end
end
