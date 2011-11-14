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

    it { should respond_to :agi }

    its(:agi) { should == :foo }

    describe '#agi' do
      let :expected_agi_command do
        Punchblock::Component::Asterisk::AGI::Command.new :name => 'Dial', :params => ['4044754842', 15]
      end

      it 'should execute an AGI command with the specified name and parameters' do
        subject.expects(:execute_component_and_await_completion).once.with expected_agi_command
        subject.agi 'Dial', '4044754842', 15
      end
    end
  end
end
