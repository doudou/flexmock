class FlexMock
  module ArgumentMatching
    module_function

    MISSING_ARG = Object.new

    def all_match?(expected_args, expected_kw, expected_block, actual_args, actual_kw, actual_block)
      all_match_args?(expected_args, actual_args) &&
        all_match_kw?(expected_kw, actual_kw) &&
        all_match_block?(expected_block, actual_block)
    end

    def all_match_args?(expected_args, actual_args)
      return true if expected_args.nil?
      return false if actual_args.size > expected_args.size
      i = 0
      while i < actual_args.size
        return false unless match?(expected_args[i], actual_args[i])
        i += 1
      end
      while i < expected_args.size
        return false unless match?(expected_args[i], MISSING_ARG)
        i += 1
      end
      true
    end

    def all_match_kw?(expected_kw, actual_kw)
      return true if expected_kw.nil?
      return expected_kw === actual_kw if expected_kw.kind_of? HashMatcher

      matched_expected_k = Set.new
      actual_kw.each do |actual_k, actual_v|
        found_match = expected_kw.find do |k, v|
          match?(k, actual_k) && match?(v, actual_v)
        end
        return false unless found_match
        matched_expected_k << found_match
      end

      return false unless matched_expected_k.size == expected_kw.keys.size

      true
    end

    def all_match_block?(expected_block, actual_block)
      return true if expected_block.nil?

      !(expected_block ^ actual_block)
    end

    # Does the expected argument match the corresponding actual value.
    def match?(expected, actual)
      expected === actual ||
      expected == actual ||
      ( Regexp === expected && expected === actual.to_s )
    end

    def missing?(arg)
      arg == MISSING_ARG
    end
  end
end
