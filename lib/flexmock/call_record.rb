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

  CallRecord = Struct.new(:method_name, :args, :kw, :block, :expectation) do
    def matches?(sym, expected_args, expected_kw, options)
      method_name == sym &&
        ArgumentMatching.all_match_args?(expected_args, args) &&
        ArgumentMatching.all_match_kw?(expected_kw, kw) &&
        matches_block?(options[:with_block])
    end

    private

    def matches_block?(block_option)
      block_option.nil? ||
        (block_option && block) ||
        (!block_option && !block)
    end

    def block_given
      block
    end
  end

end
