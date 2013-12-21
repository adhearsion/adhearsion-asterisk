require 'spec_helper'

module Adhearsion::Asterisk
  class QueueProxy
    describe AgentProxy do
      let(:queue_name)  { 'foobar' }
      let(:mock_ee)     { double 'Adhearsion::DialPlan::ExecutionEnvironment' }
      let(:mock_queue)  { double('QueueProxy', :environment => mock_ee, :name => queue_name).as_null_object }

      let(:agent_id) { 123 }

      subject { AgentProxy.new("Agent/#{agent_id}", mock_queue) }

      it 'should properly retrieve metadata' do
        metadata_name = 'status'
        mock_ee.should_receive(:variable).once.with("AGENT(#{agent_id}:#{metadata_name})")
        subject.send :agent_metadata, metadata_name
      end

      it '#logged_in? should return true if the "state" of an agent == LOGGEDIN' do
        subject.should_receive(:agent_metadata).once.with('status').and_return 'LOGGEDIN'
        subject.logged_in?.should be true

        subject.should_receive(:agent_metadata).once.with('status').and_return 'LOGGEDOUT'
        subject.logged_in?.should_not be true
      end

      it 'the AgentProxy should populate its own "id" property to the numerical ID of the "interface" with which it was constructed' do
        id = '123'
        AgentProxy.new("Agent/#{id}", mock_queue).id.should == id
        AgentProxy.new(id, mock_queue).id.should == id
      end

      it 'should pause an agent properly from a certain queue' do
        mock_ee.should_receive(:get_variable).once.with("PQMSTATUS").and_return "PAUSED"
        mock_ee.should_receive(:execute).once.with("PauseQueueMember", queue_name, "Agent/#{agent_id}")

        subject.pause!.should be true
      end

      it 'should pause an agent properly from a certain queue and return false when the agent did not exist' do
        mock_ee.should_receive(:get_variable).once.with("PQMSTATUS").and_return "NOTFOUND"
        mock_ee.should_receive(:execute).once.with("PauseQueueMember", queue_name, "Agent/#{agent_id}")

        subject.pause!.should be false
      end

      it 'should pause an agent globally properly' do
        mock_ee.should_receive(:get_variable).once.with("PQMSTATUS").and_return "PAUSED"
        mock_ee.should_receive(:execute).once.with "PauseQueueMember", nil, "Agent/#{agent_id}"

        subject.pause! :everywhere => true
      end

      it 'should unpause an agent properly' do
        mock_ee.should_receive(:get_variable).once.with("UPQMSTATUS").and_return "UNPAUSED"
        mock_ee.should_receive(:execute).once.with("UnpauseQueueMember", queue_name, "Agent/#{agent_id}")

        subject.unpause!.should be true
      end

      it 'should unpause an agent globally properly' do
        mock_ee.should_receive(:get_variable).once.with("UPQMSTATUS").and_return "UNPAUSED"
        mock_ee.should_receive(:execute).once.with("UnpauseQueueMember", nil, "Agent/#{agent_id}")

        subject.unpause!(:everywhere => true).should be true
      end

      it 'should remove an agent properly' do
        mock_ee.should_receive(:execute).once.with('RemoveQueueMember', queue_name, "Agent/#{agent_id}")
        mock_ee.should_receive(:get_variable).once.with("RQMSTATUS").and_return "REMOVED"
        subject.remove!.should be true
      end

      it 'should remove an agent properly' do
        mock_ee.should_receive(:execute).once.with('RemoveQueueMember', queue_name, "Agent/#{agent_id}")
        mock_ee.should_receive(:get_variable).once.with("RQMSTATUS").and_return "NOTINQUEUE"
        subject.remove!.should be false
      end

      it "should raise a QueueDoesNotExistError when removing an agent from a queue that doesn't exist" do
        mock_ee.should_receive(:execute).once.with("RemoveQueueMember", queue_name, "Agent/#{agent_id}")
        mock_ee.should_receive(:get_variable).once.with("RQMSTATUS").and_return "NOSUCHQUEUE"
        lambda {
          subject.remove!
        }.should raise_error QueueDoesNotExistError
      end
    end
  end
end
