class FlexMock
  module ArgumentMatching
    module_function

    MISSING_ARG = Object.new

    def all_match?(expected_args, expected_kw, actual_args, actual_kw)
      all_match_args?(expected_args, actual_args) &&
        all_match_kw?(expected_kw, actual_kw)
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

      matched_expected_k = Set.new
      actual_kw.each do |actual_k, actual_v|
        found_match = expected_kw.any? do |k, v|
          match?(k, actual_k) && match?(v, actual_v)
        end
        matched_expected_k << found_match[0]
        return false unless found_match
      end

      return false unless matched_expected_k.size == expected_kw.keys.size

      true
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
