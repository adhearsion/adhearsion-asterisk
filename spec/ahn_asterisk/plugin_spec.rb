require 'spec_helper'

module AhnAsterisk
  describe Plugin do
    it { should be_a Adhearsion::Plugin }
  end

  describe 'A DialPlan::ExecutionEnvironment with the plugin loaded' do
    before(:all) { Adhearsion::Plugin.load }

    let(:mock_call) { stub_everything 'Call', :originating_voip_platform => :punchblock }

    subject do
      Adhearsion::DialPlan::ExecutionEnvironment.create mock_call, :adhearsion
    end

    describe '#agi' do
      let :expected_agi_command do
        Punchblock::Component::Asterisk::AGI::Command.new :name => 'Dial', :params => ['4044754842', 15]
      end

      let :complete_event do
        Punchblock::Event::Complete.new.tap do |c|
          c.reason = Punchblock::Component::Asterisk::AGI::Command::Complete::Success.new :code => 200, :result => 1, :data => 'foobar'
        end
      end

      it 'should execute an AGI command with the specified name and parameters and return the response code, response and data' do
        Punchblock::Component::Asterisk::AGI::Command.any_instance.stubs :complete_event => mock('Complete', :resource => complete_event)

        subject.expects(:execute_component_and_await_completion).once.with expected_agi_command
        values = subject.agi 'Dial', '4044754842', 15
        values.should == [200, 1, 'foobar']
      end
    end

    describe '#execute' do
      it 'calls #agi and prefixes the command with EXEC' do
        subject.expects(:agi).once.with 'EXEC Dial', '4044754842', 15
        subject.execute 'Dial', '4044754842', 15
      end
    end

    describe '#verbose' do
      it 'executes the VERBOSE AGI command' do
        subject.expects(:agi).once.with 'VERBOSE', 'Foo Bar!', 15
        subject.verbose 'Foo Bar!', 15
      end
    end

    describe "#variable" do
      it "should call set_variable when Hash argument given" do
        subject.expects(:set_variable).once.with :ohai, "ur_home_erly"
        subject.variable :ohai => 'ur_home_erly'
      end

      it "should call set_variable for every Hash-key given" do
        many_args = { :a => :b, :c => :d, :e => :f, :g => :h}
        subject.expects(:set_variable).times(many_args.size)
        subject.variable many_args
      end

      it "should call get_variable for every String given" do
        variables = ["foo", "bar", :qaz, :qwerty, :baz]
        variables.each do |var|
          subject.expects(:get_variable).once.with(var).returns("X")
        end
        subject.variable(*variables).should == ["X"] * variables.size
      end

      it "should NOT return an Array when just one arg is given" do
        subject.expects(:get_variable).once.returns "lol"
        subject.variable(:foo).should_not be_a Array
      end

      it "should raise an ArgumentError when a Hash and normal args are given" do
        lambda {
          subject.variable 5, 4, 3, 2, 1, :foo => :bar
        }.should raise_error ArgumentError
      end
    end

    describe "#set_variable" do
      it "uses SET VARIABLE" do
        subject.expects(:agi).once.with 'SET VARIABLE', 'foo', 'i can " has ruby?'
        subject.set_variable 'foo', 'i can " has ruby?'
      end
    end

    describe '#get_variable' do
      it 'uses GET VARIABLE and extracts the value from the data' do
        subject.expects(:agi).once.with('GET VARIABLE', 'foo').returns [200, 1, 'bar']
        subject.get_variable('foo').should == 'bar'
      end
    end

    describe "#sip_add_header" do
      it "executes SIPAddHeader" do
        subject.expects(:execute).once.with 'SIPAddHeader', 'x-ahn-header: rubyrox'
        subject.sip_add_header "x-ahn-header", "rubyrox"
      end
    end

    describe "#sip_get_header" do
      it "uses #get_variable to get the header value" do
        value = 'jason-was-here'
        subject.expects(:get_variable).once.with('SIP_HEADER(x-ahn-header)').returns value
        subject.sip_get_header("x-ahn-header").should == value
      end
    end
  end
end
