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
  end
end
