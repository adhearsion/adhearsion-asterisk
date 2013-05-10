require 'spec_helper'

module Adhearsion::Asterisk
  class QueueProxy
    describe QueueAgentsListProxy do
      let(:queue_name)    { 'foobar' }
      let(:agent_channel) { "Agent/123" }
      let(:mock_ee)       { mock 'Adhearsion::DialPlan::ExecutionEnvironment' }
      let(:mock_queue)    { mock('QueueProxy', :environment => mock_ee, :name => queue_name).as_null_object }

      subject { QueueAgentsListProxy.new mock_queue, true }

      it 'should fetch the members with the queue name' do
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_COUNT(#{queue_name})").and_return 5
        subject.size.should == 5
      end

      it 'should not fetch a QUEUE_MEMBER_COUNT each time #count is called when caching is enabled' do
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_COUNT(#{queue_name})").and_return 0
        10.times { subject.size }
      end

      it 'when fetching agents, it should properly split by the supported delimiters' do
        mock_ee.should_receive(:get_variable).with("QUEUE_MEMBER_LIST(#{queue_name})").and_return('Agent/007,Agent/003,Zap/2')
        subject.to_a.size.should == 3
      end

      it 'when fetching agents, each array index should be an instance of AgentProxy' do
        mock_ee.should_receive(:get_variable).with("QUEUE_MEMBER_LIST(#{queue_name})").and_return('Agent/007,Agent/003,Zap/2')
        agents = subject.to_a
        agents.size.should > 0
        agents.each do |agent|
          agent.should be_a AgentProxy
        end
      end

      it '#<< should new the channel driver given as the argument to the system' do
        mock_ee.should_receive(:execute).once.with("AddQueueMember", queue_name, agent_channel, "", "", "", "")
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('ADDED')
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new agent_channel
      end

      it 'when a queue agent is dynamically added and the queue does not exist, a QueueDoesNotExistError should be raised' do
        mock_ee.should_receive(:execute).once.with("AddQueueMember", queue_name, agent_channel, "", "", "", "")
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('NOSUCHQUEUE')
        lambda {
          subject.new agent_channel
        }.should raise_error QueueDoesNotExistError
      end

      it 'when a queue agent is dynamiaclly added and the adding was successful, an AgentProxy should be returned' do
        mock_ee.should_receive(:get_variable).once.with("AQMSTATUS").and_return("ADDED")
        mock_ee.should_receive(:execute).once.with("AddQueueMember", queue_name, agent_channel, "", "", "", "")
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new(agent_channel).should be_a AgentProxy
      end

      it 'when a queue agent is dynamiaclly added and the adding was unsuccessful, a false should be returned' do
        mock_ee.should_receive(:get_variable).once.with("AQMSTATUS").and_return("MEMBERALREADY")
        mock_ee.should_receive(:execute).once.with("AddQueueMember", queue_name, agent_channel, "", "", "", "")
        subject.new(agent_channel).should be false
      end

      it 'should raise an argument when an unrecognized key is given to #new' do
        lambda {
          subject.new :foo => "bar"
        }.should raise_error ArgumentError
      end

      it 'should execute AddQueueMember with the penalty properly' do
        mock_ee.should_receive(:execute).once.with('AddQueueMember', queue_name, agent_channel, 10, '', '','')
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('ADDED')
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new agent_channel, :penalty => 10
      end

      it 'should execute AddQueueMember with the state_interface properly' do
        mock_ee.should_receive(:execute).once.with('AddQueueMember', queue_name, agent_channel, '', '', '','SIP/2302')
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('ADDED')
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new agent_channel, :state_interface => 'SIP/2302'
      end

      it 'should execute AddQueueMember properly when the name is given' do
        agent_name = 'Jay Phillips'
        mock_ee.should_receive(:execute).once.with('AddQueueMember', queue_name, agent_channel, '', '', agent_name,'')
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('ADDED')
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new agent_channel, :name => agent_name
      end

      it 'should execute AddQueueMember properly when the name, penalty, and interface is given' do
        agent_name, penalty = 'Jay Phillips', 4
        mock_ee.should_receive(:execute).once.with('AddQueueMember', queue_name, agent_channel, penalty, '', agent_name,'')
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('ADDED')
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new agent_channel, :name => agent_name, :penalty => penalty
      end

      it 'should execute AddQueueMember properly when the name, penalty, interface, and state_interface is given' do
        agent_name, penalty, state_interface = 'Jay Phillips', 4, 'SIP/2302'
        mock_ee.should_receive(:execute).once.with('AddQueueMember', queue_name, agent_channel, penalty, '', agent_name, state_interface)
        mock_ee.should_receive(:get_variable).once.with('AQMSTATUS').and_return('ADDED')
        mock_ee.should_receive(:get_variable).once.with("QUEUE_MEMBER_LIST(#{queue_name})").and_return "Agent/007,SIP/2302,Local/2510@from-internal"
        subject.new agent_channel, :name => agent_name, :penalty => penalty, :state_interface => state_interface
      end

      it "should log an agent in properly with no agent id given" do
        mock_ee.should_receive(:execute).once.with('AgentLogin', nil, 's')
        subject.login!
      end

      it 'should remove "Agent/" before the agent ID given if necessary when logging an agent in' do
        mock_ee.should_receive(:execute).once.with('AgentLogin', '007', 's')
        subject.login! 'Agent/007'

        mock_ee.should_receive(:execute).once.with('AgentLogin', '007', 's')
        subject.login! '007'
      end

      it 'should add an agent silently properly' do
        mock_ee.should_receive(:execute).once.with('AgentLogin', '007', '')
        subject.login! 'Agent/007', :silent => false

        mock_ee.should_receive(:execute).once.with('AgentLogin', '008', 's')
        subject.login! 'Agent/008', :silent => true
      end

      it 'logging an agent in should raise an ArgumentError is unrecognized arguments are given' do
        lambda {
          subject.login! 1,2,3,4,5
        }.should raise_error ArgumentError

        lambda {
          subject.login! 1337, :sssssilent => false
        }.should raise_error ArgumentError

        lambda {
          subject.login! 777, 6,5,4,3,2,1, :wee => :wee
        }.should raise_error ArgumentError
      end
    end
  end
end
