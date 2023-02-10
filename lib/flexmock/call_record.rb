#!/usr/bin/env ruby

#---
# Copyright 2003-2013 by Jim Weirich (jim.weirich@gmail.com).
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#+++

class FlexMock

  CallRecord = Struct.new(:method_name, :args, :kw, :block_given, :expectation) do
    def matches?(sym, expected_args, expected_kw, options)
      method_name == sym &&
        ArgumentMatching.all_match?(expected_args, expected_kw, args, kw) &&
        matches_block?(options[:with_block])
    end

    private

    def matches_block?(block_option)
      block_option.nil? ||
        (block_option && block_given) ||
        (!block_option && !block_given)
    end
  end

end
