#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

require 'flexmock/noop'

class FlexMock
  ####################################################################
  # Match any object
  class AnyMatcher
    def ===(target)
      true
    end
    def inspect
      "ANY"
    end
  end

  ####################################################################
  # Match only things that are equal.
  class EqualMatcher
    def initialize(obj)
      @obj = obj
    end
    def ===(target)
      @obj == target
    end
    def inspect
      "==(#{@obj.inspect})"
    end
  end

  ANY = AnyMatcher.new

  ####################################################################
  # Match only things where the block evaluates to true.
  class ProcMatcher
    def initialize(&block)
      @block = block
    end
    def ===(target)
      @block.call(target)
    end
    def inspect
      "on{...}"
    end
  end

  ####################################################################
  # Match hashes that match all the fields of +hash+.
  class HashMatcher
    def initialize(hash)
      @hash = hash
    end
    def ===(target)
      @hash.all? { |k, v| target[k] == v }
    end
    def inspect
      "hsh(#{@hash.inspect})"
    end
  end

  ####################################################################
  # Match hashes that match all the fields of +hash+.
  class KwArgsMatcher
    def initialize(expected)
      @expected = expected
    end
    def ===(target)
      return false unless target.kind_of?(Hash)
      matching = @expected.all? do |k, v|
        v === target[k] || v == target[k]
      end
      return false unless matching

      @expected.size == target.size
    end
    def inspect
      args = @expected.map do |k, v|
        k_s = case k
        when Symbol
          "#{k}: "
        else
          "#{k.inspect} => "
        end

        v_s = FlexMock.forbid_mocking("<recursive call to mocked method in #inspect>") do
          v.inspect
        end
        "#{k_s}#{v_s}"
      end
      args.join(", ")
    end
  end

  ####################################################################
  # Match objects that implement all the methods in +methods+.
  class DuckMatcher
    def initialize(methods)
      @methods = methods
    end
    def ===(target)
      @methods.all? { |m| target.respond_to?(m) }
    end
    def inspect
      "ducktype(#{@methods.map{|m| m.inspect}.join(',')})"
    end
  end

  ####################################################################
  # Match objects that implement all the methods in +methods+.
  class OptionalProcMatcher
    def initialize
    end
    def ===(target)
      ArgumentMatching.missing?(target) || Proc === target
    end
    def inspect
      "optional_proc"
    end
  end
  OPTIONAL_PROC_MATCHER = OptionalProcMatcher.new

end
