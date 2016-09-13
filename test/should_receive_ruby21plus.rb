class TestFlexMockShoulds < Minitest::Test
  include FlexMock::Minitest

  def test_with_signature_matching_sets_up_the_signature_predicate_based_on_the_provided_instance_method_keyword_arguments
    k = Class.new { def m(req_a:, req_b:, opt_c: 10, **kw_splat); end }
    FlexMock.use do |mock|
      e = mock.should_receive(:test).with_signature_matching(k.instance_method(:m))
      e = e.instance_variable_get(:@expectations).first
      validator = e.instance_variable_get(:@signature_validator)
      assert_equal 0, validator.required_arguments
      assert_equal 0, validator.optional_arguments
      refute validator.splat?
      assert_equal Set[:req_a, :req_b], validator.required_keyword_arguments
      assert_equal Set[:opt_c], validator.optional_keyword_arguments
      assert_equal true, validator.keyword_splat?
    end
  end
end


