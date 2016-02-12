require 'flexmock/rspec'

RSpec.configure do |config|
  config.mock_with :flexmock
end

describe "Dog" do
  class Dog
    def wags(arg)
      fail "SHOULD NOT BE CALLED"
    end

    def barks
      fail "SHOULD NOT BE CALLED"
    end
  end

  let(:dog) { flexmock(:on, Dog) }

  context "single calls with arguments" do
    before do
      dog.wags(:tail)
    end

    it "accepts no with" do
      expect(dog).to have_received(:wags)
    end

    it "accepts with restriction" do
      expect(dog).to have_received(:wags).with(:tail)
    end

    it "accepts not methods called" do
      expect(dog).to_not have_received(:bark)
    end

    it "rejects incorrect with restriction" do
      should_fail(/^expected wag\(:foot\) to be received by <FlexMock:Dog Mock>/i) do
        expect(dog).to have_received(:wag).with(:foot)
      end
    end

    it "rejects not on correct matcher" do
      should_fail(/^expected wags\(:tail\) to NOT be received by <FlexMock:Dog Mock>/i) do
        expect(dog).to_not have_received(:wags).with(:tail)
      end
    end
  end

  context "multiple calls with multiple arguments" do
    before do
      dog.wags(:tail)
      dog.wags(:tail)
      dog.wags(:tail)
      dog.wags(:head, :tail)
      dog.barks
      dog.barks
    end

    it "accepts wags(:tail) multiple times" do
      expect(dog).to have_received(:wags).with(:tail).times(3)
    end

    it "rejects wags(:tail) wrong times value" do
      should_fail(/^expected wags\(:tail\) to be received by <FlexMock:Dog Mock>/i) do
        expect(dog).to have_received(:wags).with(:tail).times(2)
      end
    end

    it "detects any_args" do
      expect(dog).to have_received(:wags).times(4)
    end

    it "accepts once" do
      expect(dog).to have_received(:wags).with(:head, :tail).once
    end

    it "rejects an incorrect once" do
      should_fail(/^expected wags\(:tail\) to be received by <FlexMock:Dog Mock> once/i) do
        expect(dog).to have_received(:wags).with(:tail).once
      end
    end

    it "accepts twice" do
      expect(dog).to have_received(:barks).twice
    end

    it "rejects an incorrect twice" do
      should_fail(/^expected wags\(:tail\) to be received by <FlexMock:Dog Mock> twice/) do
        expect(dog).to have_received(:wags).with(:tail).twice
      end
    end

    it "accepts never" do
      expect(dog).to have_received(:jump).never
    end

    it "rejects an incorrect never" do
      should_fail(/^expected barks\(\) to be received by <FlexMock:Dog Mock> never/i) do
        expect(dog).to have_received(:barks).with().never
      end
    end

    it "rejects an incorrect never" do
      expect(dog).to_not have_received(:jump)
    end
  end

  context "with additional validations" do
    it "accepts when correct" do
      dog.wags(:tail)
      expect(dog).to have_received(:wags).and { |arg| expect(arg).to eq(:tail) }
    end

    it "rejects when incorrect" do
      dog.wags(:tail)
      should_fail(/expected: :foot.*got: :tail/im) do
        expect(dog).to have_received(:wags).and { |arg| expect(arg).to eq(:foot) }
      end
    end

    it "rejects on all calls" do
      dog.wags(:foot)
      dog.wags(:foot)
      dog.wags(:tail)
      should_fail(/expected: :foot.*got: :tail/im) do
        expect(dog).to have_received(:wags).and { |arg| expect(arg).to eq(:foot) }
      end
    end

    it "runs the first additional block" do
      dog.wags(:tail)
      should_fail(/expected: :foot.*got: :tail/im) do
        expect(dog).to have_received(:wags).and { |args|
          expect(args).to eq(:foot)
        }.and { |args|
          expect(args).to eq(:tail)
        }
      end
    end

    it "runs the second additional block" do
      dog.wags(:tail)
      should_fail(/expected: :foot.*got: :tail/im) do
        expect(dog).to have_received(:wags).and { |args|
          expect(args).to eq(:tail)
        }.and { |args|
          expect(args).to eq(:foot)
        }
      end
    end
  end

  context "with ordinal constraints" do
    it "detects the first call" do
      dog.wags(:tail)
      dog.wags(:foot)
      expect(dog).to have_received(:wags).and { |arg| expect(arg).to eq(:tail) }.on(1)
    end

    it "detects the second call" do
      dog.wags(:tail)
      dog.wags(:foot)
      expect(dog).to have_received(:wags).and { |arg| expect(arg).to eq(:foot) }.on(2)
    end
  end

  context "with blocks" do
    before do
      dog.wags { }
      dog.barks
    end

    it "accepts wags with a block" do
      expect(dog).to have_received(:wags).with_a_block
      expect(dog).to have_received(:wags)
    end

    it "accepts barks without a block" do
      expect(dog).to have_received(:barks).without_a_block
      expect(dog).to have_received(:barks)
    end

    it "rejects wags without a block" do
      should_fail(/without a block/) do
        expect(dog).to have_received(:wags).without_a_block
      end
    end

    it "rejects barks with a block" do
      should_fail(/with a block/) do
        expect(dog).to have_received(:barks).with_a_block
      end
    end
  end

  def should_fail(message_pattern)
    failed = false
    begin
      yield
    rescue RSpec::Expectations::ExpectationNotMetError => ex
      failed = true
      expect(ex.message).to match(message_pattern)
    end
    RSpec::Expectations.fail_with "Expected block to fail with message #{message_pattern.inspect}, no failure detected" unless failed
  end
end
