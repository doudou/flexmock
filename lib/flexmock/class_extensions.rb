class Class
  # Does a class directly defines an instance method named "method_name"?
  #
  # Unlike Ruby's Class#instance_methods or #method_defined?, it ignores methods
  # that have been defined by flexmock's partial mock facility
  def flexmock_defined?(method_name)
    ancestors.any? do |m|
      methods = m.instance_methods(false)
      next if methods.include?(:__flexmock_proxy) # This is a partial mock module
      m.instance_methods(false).include?(method_name.flexmock_as_name)
    end
  end
end
