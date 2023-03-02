#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'set'
require 'flexmock/noop'
require 'flexmock/spy_describers'

class FlexMock

  ####################################################################
  # Base class for all the count validators.
  #
  class CountValidator
    include FlexMock::SpyDescribers

    def initialize(expectation, limit)
      @exp = expectation
      @limit = limit
    end

    # If the expectation has been called +n+ times, is it still
    # eligible to be called again?  The default answer compares n to
    # the established limit.
    def eligible?(n)
      n < @limit
    end

    # Human readable description of the validator
    def describe
      case @limit
      when 0
        ".never"
      when 1
        ".once"
      when 2
        ".twice"
      else
        ".times(#{@limit})"
      end
    end

    def describe_limit
      @limit.to_s
    end

    class ValidationFailed < RuntimeError
    end

    def validate_count(n, &block)
      unless yield
        raise ValidationFailed, construct_validation_count_error_message(n)
      end
    end

    private

    # Build the error message for an invalid count
    def construct_validation_count_error_message(n)
      "Method '#{@exp}' called incorrect number of times\n" +
        "#{describe_limit} matching #{calls(@limit)} expected\n" +
        "#{n} matching #{calls(n)} found\n" +
        describe_calls(@exp.mock)
    end

    # Pluralize "call"
    def calls(n)
      n == 1 ? "call" : "calls"
    end
  end

  ####################################################################
  # Validator for exact call counts.
  #
  class ExactCountValidator < CountValidator
    # Validate that the method expectation was called exactly +n+
    # times.
    def validate(n)
      validate_count(n) { @limit == n }
    end
  end

  ####################################################################
  # Validator for call counts greater than or equal to a limit.
  #
  class AtLeastCountValidator < CountValidator
    # Validate the method expectation was called no more than +n+
    # times.
    def validate(n)
      validate_count(n) { n >= @limit }
    end

    # Human readable description of the validator.
    def describe
      if @limit == 0
        ".zero_or_more_times"
      else
        ".at_least#{super}"
      end
    end

    # If the expectation has been called +n+ times, is it still
    # eligible to be called again?  Since this validator only
    # establishes a lower limit, not an upper limit, then the answer
    # is always true.
    def eligible?(n)
      true
    end

    def describe_limit
      "At least #{@limit}"
    end
  end

  ####################################################################
  # Validator for call counts less than or equal to a limit.
  #
  class AtMostCountValidator < CountValidator
    # Validate the method expectation was called at least +n+ times.
    def validate(n)
      validate_count(n) { n <= @limit }
    end

    # Human readable description of the validator
    def describe
      ".at_most#{super}"
    end

    def describe_limit
      "At most #{@limit}"
    end
  end

  # Validate that the call matches a given signature
  #
  # The validator created by {#initialize} matches any method call
  class SignatureValidator
    class ValidationFailed < RuntimeError
    end

    # The number of required arguments
    attr_reader :required_arguments
    # The number of optional arguments
    attr_reader :optional_arguments
    # Whether there is a positional argument splat
    def splat?
      @splat
    end
    # The names of required keyword arguments
    # @return [Set<Symbol>]
    attr_reader :required_keyword_arguments
    # The names of optional keyword arguments
    # @return [Set<Symbol>]
    attr_reader :optional_keyword_arguments
    # Whether there is a splat for keyword arguments (double-star)
    def keyword_splat?
      @keyword_splat
    end

    # Whether this method may have keyword arguments
    def expects_keyword_arguments?
      keyword_splat? || !required_keyword_arguments.empty? || !optional_keyword_arguments.empty?
    end

    # Whether this method may have keyword arguments
    def requires_keyword_arguments?
      !required_keyword_arguments.empty?
    end

    def initialize(
        expectation,
        required_arguments: 0,
        optional_arguments: 0,
        splat: true,
        required_keyword_arguments: [],
        optional_keyword_arguments: [],
        keyword_splat: true)
      @exp = expectation
      @required_arguments = required_arguments
      @optional_arguments = optional_arguments
      @required_keyword_arguments = required_keyword_arguments.to_set
      @optional_keyword_arguments = optional_keyword_arguments.to_set
      @splat = splat
      @keyword_splat = keyword_splat
    end

    # Whether this tests anything
    #
    # It will return if this validator would validate any set of arguments
    def null?
      splat? && keyword_splat?
    end

    def describe
      ".with_signature(
          required_arguments: #{self.required_arguments},
          optional_arguments: #{self.optional_arguments},
          required_keyword_arguments: #{self.required_keyword_arguments.to_a},
          optional_keyword_arguments: #{self.optional_keyword_arguments.to_a},
          splat: #{self.splat?},
          keyword_splat: #{self.keyword_splat?})"
    end

    # Validates whether the given arguments match the expected signature
    #
    # @param [Array] args
    # @raise ValidationFailed
    def validate(args, kw)
      args = args.dup
      kw ||= Hash.new

      last_is_proc = false
      begin
        if args.last.kind_of?(Proc)
          args.pop
          last_is_proc = true
        end
      rescue NoMethodError
      end

      if expects_keyword_arguments? && requires_keyword_arguments? && kw.empty?
        raise ValidationFailed, "#{@exp} expects keyword arguments but none were provided"
      end

      # There is currently no way to disambiguate "given a block" from "given a
      # proc as last argument" ... give some leeway in this case
      positional_count = args.size

      if required_arguments > positional_count
        if requires_keyword_arguments?
          raise ValidationFailed, "#{@exp} expects at least #{required_arguments} positional arguments but got only #{positional_count}"
        end

        if (required_arguments - positional_count) == 1 && last_is_proc
          last_is_proc = false
          positional_count += 1
        else
          raise ValidationFailed, "#{@exp} expects at least #{required_arguments} positional arguments but got only #{positional_count}"
        end
      end

      if !splat? && (required_arguments + optional_arguments) < positional_count
        if !last_is_proc || (required_arguments + optional_arguments) < positional_count - 1
          raise ValidationFailed, "#{@exp} expects at most #{required_arguments + optional_arguments} positional arguments but got #{positional_count}"
        end
      end

      missing_keyword_arguments = required_keyword_arguments.
        find_all { |k| !kw.has_key?(k) }
      if !missing_keyword_arguments.empty?
        raise ValidationFailed, "#{@exp} missing required keyword arguments #{missing_keyword_arguments.map(&:to_s).sort.join(", ")}"
      end
      if !keyword_splat?
        kw.each_key do |k|
          if !optional_keyword_arguments.include?(k) && !required_keyword_arguments.include?(k)
            raise ValidationFailed, "#{@exp} given unexpected keyword argument #{k}"
          end
        end
      end
    end

    # Create a validator that represents the signature of an existing method
    def self.from_instance_method(exp, instance_method)
      required_arguments, optional_arguments, splat = 0, 0, false
      required_keyword_arguments, optional_keyword_arguments, keyword_splat = Set.new, Set.new, false
      instance_method.parameters.each do |type, name|
        case type
        when :req then required_arguments += 1
        when :opt then optional_arguments += 1
        when :rest then splat = true
        when :keyreq then required_keyword_arguments << name
        when :key then optional_keyword_arguments << name
        when :keyrest then keyword_splat = true
        when :block
        else raise ArgumentError, "cannot interpret parameter type #{type}"
        end
      end
      new(exp,
          required_arguments: required_arguments,
          optional_arguments: optional_arguments,
          splat: splat,
          required_keyword_arguments: required_keyword_arguments,
          optional_keyword_arguments: optional_keyword_arguments,
          keyword_splat: keyword_splat)
    end
  end
end
