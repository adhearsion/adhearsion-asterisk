require 'spec_helper'

module Adhearsion::Asterisk
  describe CallControllerMethods do
    describe "mixed in to a CallController" do

      subject { Adhearsion::CallController.new mock('Call') }

      before { Adhearsion::CallController.mixin CallControllerMethods }

      describe '#agi' do
        let :expected_agi_command do
          Punchblock::Component::Asterisk::AGI::Command.new :name => 'Dial', :params => ['4044754842', 15]
        end

        let :complete_event do
          Punchblock::Event::Complete.new.tap do |c|
            c.reason = Punchblock::Component::Asterisk::AGI::Command::Complete::Success.new :code => 200, :result => 1, :data => 'foobar'
          end
        end

        before { Punchblock::Component::Asterisk::AGI::Command.any_instance.stubs :complete_event => complete_event }

        it 'should execute an AGI command with the specified name and parameters and return the response code, response and data' do
          subject.expects(:execute_component_and_await_completion).once.with expected_agi_command
          values = subject.agi 'Dial', '4044754842', 15
          values.should == [200, 1, 'foobar']
        end

        context 'when AGI terminates because of a hangup' do
          let :complete_event do
            Punchblock::Event::Complete.new.tap do |c|
              c.reason = Punchblock::Event::Complete::Hangup.new
            end
          end

          it 'should raise Adhearsion::Call::Hangup' do
            subject.expects(:execute_component_and_await_completion).once.with expected_agi_command
            lambda { subject.agi 'Dial', '4044754842', 15 }.should raise_error(Adhearsion::Call::Hangup)
          end
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

      describe '#enable_feature' do
        it 'it should fetch the variable for DYNAMIC_FEATURES at first' do
          subject.expects(:variable).once.with("DYNAMIC_FEATURES").throws(:got_variable)
          expect {
            subject.enable_feature :foobar
          }.to throw_symbol :got_variable
        end

        it 'should check Adhearsion::Asterisk::Plugin::DYNAMIC_FEATURE_EXTENSIONS mapping for configuration setters' do
          feature_name = :attended_transfer

          assertion = lambda do |arg|
            arg.should == :this_is_the_right_arg
            throw :inside_assertion!
          end

          # I had to do this ugly hack because of a bug in Flexmock which prevented me from mocking out Hash#[]  :(
          # FIXME: mock Hash
          #        ...DYNAMIC_FEATURE_EXTENSIONS.expects(feature_name => assertion)

          old_hash_feature_extension = Adhearsion::Asterisk::CallControllerMethods::DYNAMIC_FEATURE_EXTENSIONS[feature_name]
          begin
            Adhearsion::Asterisk::CallControllerMethods::DYNAMIC_FEATURE_EXTENSIONS[feature_name] = assertion

            subject.expects(:enable_feature).once.with(feature_name, :this_is_the_right_arg).throws :inside_assertion!
            expect { subject.enable_feature(feature_name, :this_is_the_right_arg)}.to throw_symbol :inside_assertion!
          ensure
            Adhearsion::Asterisk::CallControllerMethods::DYNAMIC_FEATURE_EXTENSIONS[feature_name] = old_hash_feature_extension
          end
        end

        it 'should separate enabled features with a "#"' do
          subject.expects(:variable).once.with("DYNAMIC_FEATURES").returns("one")
          subject.expects(:variable).once.with("DYNAMIC_FEATURES" => 'one#bar')
          subject.enable_feature "bar"
        end

        it 'should not add duplicate enabled dynamic features' do
          subject.expects(:variable).once.returns('eins#zwei')
          subject.enable_feature "eins"
        end

        it 'should raise an ArgumentError if optional options are given when DYNAMIC_FEATURE_EXTENSIONS does not have a key for the feature name' do
          expect { subject.enable_feature :this_is_not_recognized,
                                          :these_features => "are not going to be recognized"
                 }.to raise_error ArgumentError
        end

        it 'enabling :attended_transfer should actually enable the atxfer feature' do
          subject.expects(:variable).once.with("DYNAMIC_FEATURES").returns ''
          subject.expects(:variable).once.with("DYNAMIC_FEATURES" => 'atxfer')
          subject.enable_feature :attended_transfer
        end

        it 'the :context optional option when enabling :attended_transfer should set the TRANSFER_CONTEXT variable to the String supplied as a Hash value' do
          context_name = "direct_dial"
          subject.expects(:variable).once.with("DYNAMIC_FEATURES").returns ''
          subject.expects(:variable).once.with("DYNAMIC_FEATURES" => 'atxfer')
          subject.expects(:variable).once.with("TRANSFER_CONTEXT" => context_name)
          subject.enable_feature :attended_transfer, :context => context_name
        end

        it 'enabling :attended_transfer should not add a duplicate if atxfer has been enabled, but it should still set the TRANSFER_CONTEXT variable' do
          context_name = 'blah'
          subject.expects(:variable).once.with('DYNAMIC_FEATURES').returns 'atxfer'
          subject.expects(:variable).once.with('TRANSFER_CONTEXT' => context_name)
          subject.enable_feature :attended_transfer, :context => context_name
        end
      end

      describe '#disable_feature' do
        it "should properly remove the feature from the DYNAMIC_FEATURES variable" do
          subject.expects(:variable).once.with('DYNAMIC_FEATURES').returns 'foobar#qaz'
          subject.expects(:variable).once.with('DYNAMIC_FEATURES' => 'qaz')
          subject.disable_feature "foobar"
        end

        it "should not re-set the variable if the feature wasn't enabled in the first place" do
          subject.expects(:variable).once.with('DYNAMIC_FEATURES').returns 'atxfer'
          subject.expects(:variable).never
          subject.disable_feature "jay"
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

      describe '#join' do
        it "should pass the 'd' flag when no options are given" do
          conference_id = "123"
          subject.expects(:execute).once.with("MeetMe", conference_id, "d", nil)
          subject.meetme conference_id
        end

        it "should pass through any given flags with 'd' appended to it if necessary" do
          conference_id, flags = "1000", "zomgs"
          subject.expects(:execute).once.with("MeetMe", conference_id, flags + "d", nil)
          subject.meetme conference_id, :options => flags
        end

        it "should NOT pass the 'd' flag when requiring static conferences" do
          conference_id, options = "1000", {:use_static_conf => true}
          subject.expects(:execute).once.with("MeetMe", conference_id, "", nil)
          subject.meetme conference_id, options
        end

        it "should raise an ArgumentError when the pin is not numerical" do
          lambda {
            subject.expects(:execute).never
            subject.meetme 3333, :pin => "letters are bad, mkay?!1"
          }.should raise_error ArgumentError
        end

        it "should strip out illegal characters from a conference name" do
          bizarre_conference_name = "a-    bc!d&&e--`"
          normal_conference_name = "abcde"
          subject.expects(:execute).twice.with("MeetMe", normal_conference_name, "d", nil)

          subject.meetme bizarre_conference_name
          subject.meetme normal_conference_name
        end

        it "should allow textual conference names" do
          lambda {
            subject.expects(:execute).once
            subject.meetme "david bowie's pants"
          }.should_not raise_error
        end
      end

      describe '#voicemail' do
        it 'should not send the context name when none is given' do
          subject.expects(:execute).once.with('voicemail', 123, '').throws :sent_voicemail!
          lambda { subject.voicemail 123 }.should throw_symbol(:sent_voicemail!)
        end

        it 'should send the context name when one is given' do
          mailbox_number, context_name = 333, 'doesntmatter'
          subject.expects(:execute).once.with('voicemail', "#{mailbox_number}@#{context_name}", '').throws :sent_voicemail!
          lambda { subject.voicemail(context_name => mailbox_number) }.should throw_symbol(:sent_voicemail!)
        end

        it 'should pass in the s option if :skip => true' do
          mailbox_number = '012'
          subject.expects(:execute).once.with('voicemail', mailbox_number, 's').throws :sent_voicemail!
          lambda { subject.voicemail(mailbox_number, :skip => true) }.should throw_symbol(:sent_voicemail!)
        end

        it 'should combine mailbox numbers with the context name given when both are given' do
          subject.expects(:variable).with("VMSTATUS").returns 'SUCCESS'
          context   = "lolcats"
          mailboxes = [1,2,3,4,5]
          mailboxes_with_context = mailboxes.map { |mailbox| [mailbox, context].join '@' }
          subject.expects(:execute).once.with('voicemail', mailboxes_with_context.join('&'), '')
          subject.voicemail context => mailboxes
        end

        it 'should raise an argument error if the mailbox number is not numerical' do
          lambda {
            subject.voicemail :foo => "bar"
          }.should raise_error ArgumentError
        end

        it 'should raise an argument error if too many arguments are supplied' do
          lambda {
            subject.voicemail "wtfisthisargument", :context_name => 123, :greeting => :busy
          }.should raise_error ArgumentError
        end

        it 'should raise an ArgumentError if multiple context names are given' do
          lambda {
            subject.voicemail :one => [1,2,3], :two => [11,22,33]
          }.should raise_error ArgumentError
        end

        it "should raise an ArgumentError when the :greeting value isn't recognized" do
          lambda {
            subject.voicemail :context_name => 123, :greeting => :zomgz
          }.should raise_error ArgumentError
        end

        it 'should pass in the u option if :greeting => :unavailable' do
          mailbox_number = '776'
          subject.expects(:execute).once.with('voicemail', mailbox_number, 'u').throws :sent_voicemail!
          lambda { subject.voicemail(mailbox_number, :greeting => :unavailable) }.should throw_symbol(:sent_voicemail!)
        end

        it 'should pass in both the skip and greeting options if both are supplied' do
          mailbox_number = '4'
          subject.expects(:execute).once.with('voicemail', mailbox_number, 'u').throws :sent_voicemail!
          lambda { subject.voicemail(mailbox_number, :greeting => :unavailable) }.should throw_symbol(:sent_voicemail!)
        end

        it 'should raise an ArgumentError if mailbox_number is blank?()' do
          lambda {
            subject.voicemail ''
          }.should raise_error ArgumentError

          lambda {
            subject.voicemail nil
          }.should raise_error ArgumentError
        end

        it 'should pass in the b option if :gretting => :busy' do
          mailbox_number = '1'
          subject.expects(:execute).once.with('voicemail', mailbox_number, 'b').throws :sent_voicemail!
          lambda { subject.voicemail(mailbox_number, :greeting => :busy) }.should throw_symbol(:sent_voicemail!)
        end

        it 'should return true if VMSTATUS == "SUCCESS"' do
          subject.expects(:execute).once
          subject.expects(:variable).once.with('VMSTATUS').returns "SUCCESS"
          subject.voicemail(3).should be true
        end

        it 'should return false if VMSTATUS == "USEREXIT"' do
          subject.expects(:execute).once
          subject.expects(:variable).once.with('VMSTATUS').returns "USEREXIT"
          subject.voicemail(2).should be false
        end

        it 'should return nil if VMSTATUS == "FAILED"' do
          subject.expects(:execute).once
          subject.expects(:variable).once.with('VMSTATUS').returns "FAILED"
          subject.voicemail(2).should be nil
        end
      end

      describe '#voicemail_main' do
        it "the :folder Hash key argument should wrap the value in a()" do
          folder = "foobar"
          mailbox = 81
          subject.expects(:execute).once.with("VoiceMailMain", "#{mailbox}","a(#{folder})")
          subject.voicemail_main :mailbox => mailbox, :folder => folder
        end

        it ':authenticate should pass in the "s" option if given false' do
          mailbox = 333
          subject.expects(:execute).once.with("VoiceMailMain", "#{mailbox}","s")
          subject.voicemail_main :mailbox => mailbox, :authenticate => false
        end

        it ':authenticate should pass in the s option if given false' do
          mailbox = 55
          subject.expects(:execute).once.with("VoiceMailMain", "#{mailbox}")
          subject.voicemail_main :mailbox => mailbox, :authenticate => true
        end

        it 'should not pass any flags only a mailbox is given' do
          mailbox = "1"
          subject.expects(:execute).once.with("VoiceMailMain", "#{mailbox}")
          subject.voicemail_main :mailbox => mailbox
        end

        it 'when given no mailbox or context an empty string should be passed to execute as the first argument' do
          subject.expects(:execute).once.with("VoiceMailMain", "", "s")
          subject.voicemail_main :authenticate => false
        end

        it 'should properly concatenate the options when given multiple ones' do
          folder = "ohai"
          mailbox = 9999
          subject.expects(:execute).once.with("VoiceMailMain", "#{mailbox}", "sa(#{folder})")
          subject.voicemail_main :mailbox => mailbox, :authenticate => false, :folder => folder
        end

        it 'should not require any arguments' do
          subject.expects(:execute).once.with("VoiceMailMain")
          subject.voicemail_main
        end

        it 'should pass in the "@context_name" part in if a :context is given and no mailbox is given' do
          context_name = "icanhascheezburger"
          subject.expects(:execute).once.with("VoiceMailMain", "@#{context_name}")
          subject.voicemail_main :context => context_name
        end

        it "should raise an exception if the folder has a space or malformed characters in it" do
          ["i has a space", "exclaim!", ",", ""].each do |bad_folder_name|
            lambda {
              subject.voicemail_main :mailbox => 123, :folder => bad_folder_name
            }.should raise_error ArgumentError
          end
        end
      end

      describe "#queue" do
        it 'should not create separate objects for queues with basically the same name' do
          subject.queue('foo').should be subject.queue('foo')
          subject.queue('bar').should be subject.queue(:bar)
        end

        it "should return an instance of QueueProxy" do
          subject.queue("foobar").should be_a_kind_of Adhearsion::Asterisk::QueueProxy
        end

        it "should set the QueueProxy's name" do
          subject.queue("foobar").name.should == 'foobar'
        end

        it "should set the QueueProxy's environment" do
          subject.queue("foobar").environment.should == subject
        end
      end#describe #queue

      describe "#play_time" do
        let(:date) { Date.parse('2011-10-24') }
        let(:date_format) { 'ABdY' }
        let(:time) { Time.at(875121313) }
        let(:time_format) { 'IMp' }

        it "if a Date object is passed in, SayUnixTime is sent with the argument and format" do
          subject.expects(:execute).once.with("SayUnixTime", date.to_time.to_i, "", date_format)
          subject.play_time(date, :format => date_format)
        end

        it "if a Time object is passed in, SayUnixTime is sent with the argument and format" do
          subject.expects(:execute).once.with("SayUnixTime", time.to_i, "", time_format)
          subject.play_time(time, :format => time_format)
        end

        it "if a Time object is passed in alone, SayUnixTime is sent with the argument and the default format" do
          subject.expects(:execute).once.with("SayUnixTime", time.to_i, "", "")
          subject.play_time(time)
        end

      end

      describe "#play_numeric" do
        let(:numeric) { 20 }
        it "should send the correct command SayNumber playing a numeric argument" do
          subject.expects(:execute).once.with("SayNumber", numeric)
          subject.play_numeric(numeric)
        end
      end

      describe "#play_digits" do
        let(:numeric) { 20 }
        it "should send the correct command SayDigits playing a numeric argument" do
          subject.expects(:execute).once.with("SayDigits", numeric)
          subject.play_digits(numeric)
        end
      end

      describe "#play_soundfile" do
        let(:audiofile) { "tt-monkeys" }
        it "should send the correct command Playback playing an audio file" do
          subject.expects(:execute).once.with("Playback", audiofile)
          # subject.expects(:execute).once.with("Playback", audiofile).returns([200, 1, nil])
          subject.expects(:get_variable).once.with("PLAYBACKSTATUS").returns(PLAYBACK_SUCCESS)
          subject.play_soundfile(audiofile)
        end

        it "should return false if playback fails" do
          subject.expects(:execute).once.with("Playback", audiofile)
          subject.expects(:get_variable).once.with("PLAYBACKSTATUS").returns('FAILED')
          subject.play_soundfile(audiofile).should == false
        end
      end
    end
  end#main describe
end