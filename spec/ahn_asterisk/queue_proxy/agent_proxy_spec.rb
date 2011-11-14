require 'spec_helper'

module AhnAsterisk
  class QueueProxy
    describe AgentProxy do
      let(:queue_name)  { 'foobar' }
      let(:mock_ee)     { mock 'Adhearsion::DialPlan::ExecutionEnvironment' }
      let(:mock_queue)  { stub_everything 'QueueProxy', :environment => mock_ee, :name => queue_name }

      let(:agent_id) { 123 }

      subject { AgentProxy.new("Agent/#{agent_id}", mock_queue) }

      it 'should properly retrieve metadata' do
        metadata_name = 'status'
        mock_ee.expects(:variable).once.with("AGENT(#{agent_id}:#{metadata_name})")
        subject.send :agent_metadata, metadata_name
      end

      it '#logged_in? should return true if the "state" of an agent == LOGGEDIN' do
        subject.expects(:agent_metadata).once.with('status').returns 'LOGGEDIN'
        subject.logged_in?.should be true

        subject.expects(:agent_metadata).once.with('status').returns 'LOGGEDOUT'
        subject.logged_in?.should_not be true
      end

      it 'the AgentProxy should populate its own "id" property to the numerical ID of the "interface" with which it was constructed' do
        id = '123'
        AgentProxy.new("Agent/#{id}", mock_queue).id.should == id
        AgentProxy.new(id, mock_queue).id.should == id
      end

      it 'should pause an agent properly from a certain queue' do
        mock_ee.expects(:get_variable).once.with("PQMSTATUS").returns "PAUSED"
        mock_ee.expects(:execute).once.with("PauseQueueMember", queue_name, "Agent/#{agent_id}")

        subject.pause!.should be true
      end

      it 'should pause an agent properly from a certain queue and return false when the agent did not exist' do
        mock_ee.expects(:get_variable).once.with("PQMSTATUS").returns "NOTFOUND"
        mock_ee.expects(:execute).once.with("PauseQueueMember", queue_name, "Agent/#{agent_id}")

        subject.pause!.should be false
      end

      it 'should pause an agent globally properly' do
        mock_ee.expects(:get_variable).once.with("PQMSTATUS").returns "PAUSED"
        mock_ee.expects(:execute).once.with "PauseQueueMember", nil, "Agent/#{agent_id}"

        subject.pause! :everywhere => true
      end

      it 'should unpause an agent properly' do
        mock_ee.expects(:get_variable).once.with("UPQMSTATUS").returns "UNPAUSED"
        mock_ee.expects(:execute).once.with("UnpauseQueueMember", queue_name, "Agent/#{agent_id}")

        subject.unpause!.should be true
      end

      it 'should unpause an agent globally properly' do
        mock_ee.expects(:get_variable).once.with("UPQMSTATUS").returns "UNPAUSED"
        mock_ee.expects(:execute).once.with("UnpauseQueueMember", nil, "Agent/#{agent_id}")

        subject.unpause!(:everywhere => true).should be true
      end

      it 'should remove an agent properly' do
        mock_ee.expects(:execute).once.with('RemoveQueueMember', queue_name, "Agent/#{agent_id}")
        mock_ee.expects(:get_variable).once.with("RQMSTATUS").returns "REMOVED"
        subject.remove!.should be true
      end

      it 'should remove an agent properly' do
        mock_ee.expects(:execute).once.with('RemoveQueueMember', queue_name, "Agent/#{agent_id}")
        mock_ee.expects(:get_variable).once.with("RQMSTATUS").returns "NOTINQUEUE"
        subject.remove!.should be false
      end

      it "should raise a QueueDoesNotExistError when removing an agent from a queue that doesn't exist" do
        mock_ee.expects(:execute).once.with("RemoveQueueMember", queue_name, "Agent/#{agent_id}")
        mock_ee.expects(:get_variable).once.with("RQMSTATUS").returns "NOSUCHQUEUE"
        lambda {
          subject.remove!
        }.should raise_error QueueDoesNotExistError
      end
    end
  end
end
