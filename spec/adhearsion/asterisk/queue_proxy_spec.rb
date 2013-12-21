require 'spec_helper'

module Adhearsion::Asterisk
  describe QueueProxy do
    let(:queue_name)  { 'foobar' }
    let(:mock_ee)     { double 'Adhearsion::DialPlan::ExecutionEnvironment' }

    subject { QueueProxy.new queue_name, mock_ee }

    it "should respond to #join!, #agents" do
      %w[join! agents].each do |method|
        subject.should respond_to(method)
      end
    end

    it 'should return a QueueAgentsListProxy when #agents is called' do
      subject.agents.should be_a Adhearsion::Asterisk::QueueProxy::QueueAgentsListProxy
    end

    describe '#join' do
      it 'should properly join a queue' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "FULL"
        subject.join!
      end

      it 'should return a symbol representing the result of joining the queue' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "TIMEOUT"
        subject.join!.should be :timeout
      end

      it 'should return :completed after joining the queue and being connected' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return nil
        subject.join!.should be :completed
      end

      it 'should join a queue with a timeout properly' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "", '', '', '60', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :timeout => 1.minute
      end

      it 'should join a queue with an announcement file properly' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "", '', 'custom_announcement_file_here', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :announce => 'custom_announcement_file_here'
      end

      it 'should join a queue with an agi script properly' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, '', '', '', '','agi://localhost/queue_agi_test')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINUNAVAIL"
        subject.join! :agi => 'agi://localhost/queue_agi_test'
      end

      it 'should join a queue with allow_transfer properly' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "Tt", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_transfer => :everyone

        mock_ee.should_receive(:execute).once.with("queue", queue_name, "T", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_transfer => :caller

        mock_ee.should_receive(:execute).once.with("queue", queue_name, "t", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_transfer => :agent
      end

      it 'should join a queue with allow_hangup properly' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "Hh", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_hangup => :everyone

        mock_ee.should_receive(:execute).once.with("queue", queue_name, "H", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_hangup => :caller

        mock_ee.should_receive(:execute).once.with("queue", queue_name, "h", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_hangup => :agent
      end

      it 'should join a queue properly with the :play argument' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "r", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :play => :ringing

        mock_ee.should_receive(:execute).once.with("queue", queue_name, "", '', '', '', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :play => :music
      end

      it 'joining a queue with many options specified' do
        mock_ee.should_receive(:execute).once.with("queue", queue_name, "rtHh", '', '', '120', '')
        mock_ee.should_receive(:get_variable).once.with("QUEUESTATUS").and_return "JOINEMPTY"
        subject.join! :allow_transfer => :agent, :timeout => 2.minutes,
                      :play => :ringing, :allow_hangup => :everyone
      end

      it 'should raise an ArgumentError when unrecognized Hash key arguments are given' do
        lambda {
          subject.join! :misspelled => true
        }.should raise_error ArgumentError
      end
    end

    describe 'agents' do
     it 'should raise an argument error with unrecognized key' do
        lambda {
          subject.agents(:cached => true) # common typo
        }.should raise_error ArgumentError
      end
    end

    it 'should return a correct boolean for #exists?' do
      mock_ee.should_receive(:execute).once.with("RemoveQueueMember", queue_name, "SIP/AdhearsionQueueExistenceCheck")
      mock_ee.should_receive(:get_variable).once.with("RQMSTATUS").and_return "NOTINQUEUE"
      subject.exists?.should be true

      mock_ee.should_receive(:execute).once.with("RemoveQueueMember", queue_name, "SIP/AdhearsionQueueExistenceCheck")
      mock_ee.should_receive(:get_variable).once.with("RQMSTATUS").and_return "NOSUCHQUEUE"
      subject.exists?.should be false
    end

    it 'waiting_count for a queue that does exist' do
      mock_ee.should_receive(:get_variable).once.with("QUEUE_WAITING_COUNT(#{queue_name})").and_return "50"
      subject.should_receive(:exists?).once.and_return true
      subject.waiting_count.should == 50
    end

    it 'waiting_count for a queue that does not exist' do
      lambda {
        subject.should_receive(:exists?).once.and_return false
        subject.waiting_count
      }.should raise_error Adhearsion::Asterisk::QueueProxy::QueueDoesNotExistError
    end

    it 'empty? should call waiting_count' do
      subject.should_receive(:waiting_count).once.and_return 0
      subject.empty?.should be true

      subject.should_receive(:waiting_count).once.and_return 99
      subject.empty?.should_not be true
    end

    it 'any? should call waiting_count' do
      subject.should_receive(:waiting_count).once.and_return 0
      subject.any?.should be false

      subject.should_receive(:waiting_count).once.and_return 99
      subject.any?.should be true
    end
  end
end
