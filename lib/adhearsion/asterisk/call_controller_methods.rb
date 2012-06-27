module Adhearsion
  module Asterisk
    PLAYBACK_SUCCESS = 'SUCCESS' unless defined? PLAYBACK_SUCCESS

    module CallControllerMethods
      DYNAMIC_FEATURE_EXTENSIONS = {
        :attended_transfer => lambda do |options|
          variable "TRANSFER_CONTEXT" => options[:context] if options && options.has_key?(:context)
          extend_dynamic_features_with "atxfer"
        end,
        :blind_transfer => lambda do |options|
          variable "TRANSFER_CONTEXT" => options[:context] if options && options.has_key?(:context)
          extend_dynamic_features_with 'blindxfer'
        end
      } unless defined? DYNAMIC_FEATURE_EXTENSIONS

      def agi(name, *params)
        component = Punchblock::Component::Asterisk::AGI::Command.new :name => name, :params => params
        execute_component_and_await_completion component
        complete_reason = component.complete_event.reason
        raise Adhearsion::Call::Hangup if complete_reason.is_a?(Punchblock::Event::Complete::Hangup)
        [:code, :result, :data].map { |p| complete_reason.send p }
      end

      #
      # This asterisk dialplan command allows you to instruct Asterisk to start applications
      # which are typically run from extensions.conf and do not have AGI command equivalents.
      #
      # For example, if there are specific asterisk modules you have loaded that will not be
      # available through the standard commands provided through FAGI - then you can use EXEC.
      #
      # @example Using execute in this way will add a header to an existing SIP call.
      #   execute 'SIPAddHeader', "Call-Info: answer-after=0"
      #
      # @see http://www.voip-info.org/wiki/view/Asterisk+-+documentation+of+application+commands Asterisk Dialplan Commands
      #
      def execute(name, *params)
        agi "EXEC #{name}", *params
      end

      #
      # Sends a message to the console via the verbose message system.
      #
      # @param [String] message
      # @param [Integer] level
      #
      # @return the result of the command
      #
      # @example Use this command to inform someone watching the Asterisk console
      # of actions happening within Adhearsion.
      #   verbose 'Processing call with Adhearsion' 3
      #
      # @see http://www.voip-info.org/wiki/view/verbose
      #
      def verbose(message, level = nil)
        agi 'VERBOSE', message, level
      end

      # A high-level way of enabling features you create/uncomment from features.conf.
      #
      # Certain Symbol features you enable (as defined in DYNAMIC_FEATURE_EXTENSIONS) have optional
      # arguments that you can also specify here. The usage examples show how to do this.
      #
      # Usage examples:
      #
      #   enable_feature :attended_transfer                        # Enables "atxfer"
      #
      #   enable_feature :attended_transfer, :context => "my_dial" # Enables "atxfer" and then
      #                                                            # sets "TRANSFER_CONTEXT" to :context's value
      #
      #   enable_feature :blind_transfer, :context => 'my_dial'    # Enables 'blindxfer' and sets TRANSFER_CONTEXT
      #
      #   enable_feature "foobar"                                  # Enables "foobar"
      #
      #   enable_feature("dup"); enable_feature("dup")             # Enables "dup" only once.
      #
      # def voicemail(*args)
      #   options_hash    = args.last.kind_of?(Hash) ? args.pop : {}
      #   mailbox_number  = args.shift
      #   greeting_option = options_hash.delete :greeting
      #
      def enable_feature(*args)
        feature_name, optional_options = args.flatten

        if DYNAMIC_FEATURE_EXTENSIONS.has_key? feature_name
          instance_exec(optional_options, &DYNAMIC_FEATURE_EXTENSIONS[feature_name])
        else
          unless optional_options.nil? or optional_options.empty?
            raise ArgumentError, "You cannot supply optional options when the feature name is " +
                                 "not internally recognized!"
          end
          extend_dynamic_features_with feature_name
        end
      end

      # Disables a feature name specified in features.conf. If you're disabling it, it was probably
      # set by enable_feature().
      #
      # @param [String] feature_name
      def disable_feature(feature_name)
        enabled_features_variable = variable 'DYNAMIC_FEATURES'
        enabled_features = enabled_features_variable.split('#')
        if enabled_features.include? feature_name
          enabled_features.delete feature_name
          variable 'DYNAMIC_FEATURES' => enabled_features.join('#')
        end
      end

      # helper method that should probably should private...
      def extend_dynamic_features_with(feature_name)
        current_variable = variable("DYNAMIC_FEATURES") || ''
        enabled_features = current_variable.split '#'
        unless enabled_features.include? feature_name
          enabled_features << feature_name
          variable "DYNAMIC_FEATURES" => enabled_features.join('#')
        end
      end

      #
      # Issue this command to access a channel variable that exists in the asterisk dialplan (i.e. extensions.conf)
      # Use get_variable to pass information from other modules or high level configurations from the asterisk dialplan
      # to the adhearsion dialplan.
      #
      # @param [String] variable_name
      #
      # @see: http://www.voip-info.org/wiki/view/get+variable Asterisk Get Variable
      #
      def get_variable(variable_name)
        code, result, data = agi "GET VARIABLE", variable_name
        data
      end

      #
      # Pass information back to the asterisk dial plan.
      #
      # Keep in mind that the variables are not global variables. These variables only exist for the channel
      # related to the call that is being serviced by the particular instance of your adhearsion application.
      # You will not be able to pass information back to the asterisk dialplan for other instances of your adhearsion
      # application to share. Once the channel is "hungup" then the variables are cleared and their information is gone.
      #
      # @param [String] variable_name
      # @param [String] value
      #
      # @see http://www.voip-info.org/wiki/view/set+variable Asterisk Set Variable
      #
      def set_variable(variable_name, value)
        agi "SET VARIABLE", variable_name, value
      end

      #
      # Issue the command to add a custom SIP header to the current call channel
      # example use: sip_add_header("x-ahn-test", "rubyrox")
      #
      # @param[String] the name of the SIP header
      # @param[String] the value of the SIP header
      #
      # @return [String] the Asterisk response
      #
      # @see http://www.voip-info.org/wiki/index.php?page=Asterisk+cmd+SIPAddHeader Asterisk SIPAddHeader
      #
      def sip_add_header(header, value)
        execute "SIPAddHeader", "#{header}: #{value}"
      end

      #
      # Issue the command to fetch a SIP header from the current call channel
      # example use: sip_get_header("x-ahn-test")
      #
      # @param[String] the name of the SIP header to get
      #
      # @return [String] the Asterisk response
      #
      # @see http://www.voip-info.org/wiki/index.php?page=Asterisk+cmd+SIPGetHeader Asterisk SIPGetHeader
      #
      def sip_get_header(header)
        get_variable "SIP_HEADER(#{header})"
      end

      #
      # Allows you to either set or get a channel variable from Asterisk.
      # The method takes a hash key/value pair if you would like to set a variable
      # Or a single string with the variable to get from Asterisk
      #
      def variable(*args)
        if args.last.kind_of? Hash
          assignments = args.pop
          raise ArgumentError, "Can't mix variable setting and fetching!" if args.any?
          assignments.each_pair do |key, value|
            set_variable key, value
          end
        else
          if args.size == 1
            get_variable args.first
          else
            args.map { |var| get_variable var }
          end
        end
      end

      #
      # Used to join a particular conference with the MeetMe application. To use MeetMe, be sure you
      # have a proper timing device configured on your Asterisk box. MeetMe is Asterisk's built-in
      # conferencing program.
      #
      # @param [String] conference_id
      # @param [Hash] options
      #
      # @see http://www.voip-info.org/wiki-Asterisk+cmd+MeetMe Asterisk Meetme Application Information
      #
      def meetme(conference_id, options = {})
        conference_id = conference_id.to_s.scan(/\w/).join
        command_flags = options[:options].to_s # This is a passthrough string straight to Asterisk
        pin = options[:pin]
        raise ArgumentError, "A conference PIN number must be numerical!" if pin && pin.to_s !~ /^\d+$/

        # To disable dynamic conference creation set :use_static_conf => true
        use_static_conf = options.has_key?(:use_static_conf) ? options[:use_static_conf] : false

        # The 'd' option of MeetMe creates conferences dynamically.
        command_flags += 'd' unless command_flags.include?('d') || use_static_conf

        execute "MeetMe", conference_id, command_flags, options[:pin]
      end

      #
      # Send a caller to a voicemail box to leave a message.
      #
      # The method takes the mailbox_number of the user to leave a message for and a
      # greeting_option that will determine which message gets played to the caller.
      #
      # @see http://www.voip-info.org/tiki-index.php?page=Asterisk+cmd+VoiceMail Asterisk Voicemail
      #
      def voicemail(*args)
        options_hash    = args.last.kind_of?(Hash) ? args.pop : {}
        mailbox_number  = args.shift
        greeting_option = options_hash.delete :greeting
        skip_option     = options_hash.delete :skip
        raise ArgumentError, 'You supplied too many arguments!' if mailbox_number && options_hash.any?

        greeting_option = case greeting_option
        when :busy then 'b'
        when :unavailable then 'u'
        when nil then nil
        else raise ArgumentError, "Unrecognized greeting #{greeting_option}"
        end
        skip_option &&= 's'
        options = "#{greeting_option}#{skip_option}"

        raise ArgumentError, "Mailbox cannot be blank!" if !mailbox_number.nil? && mailbox_number.blank?
        number_with_context = if mailbox_number then mailbox_number else
          raise ArgumentError, "You must supply ONE context name!" unless options_hash.size == 1
          context_name, mailboxes = options_hash.to_a.first
          Array(mailboxes).map do |mailbox|
            raise ArgumentError, "Mailbox numbers must be numerical!" unless mailbox.to_s =~ /^\d+$/
            [mailbox, context_name].join '@'
          end.join '&'
        end

        execute 'voicemail', number_with_context, options
        case variable('VMSTATUS')
        when 'SUCCESS' then true
        when 'USEREXIT' then false
        else nil
        end
      end

      #
      # The voicemail_main method puts a caller into the voicemail system to fetch their voicemail
      # or set options for their voicemail box.
      #
      # @param [Hash] options
      #
      # @see http://www.voip-info.org/wiki-Asterisk+cmd+VoiceMailMain Asterisk VoiceMailMain Command
      #
      def voicemail_main(options = {})
        mailbox, context, folder = options.values_at :mailbox, :context, :folder
        authenticate = options.has_key?(:authenticate) ? options[:authenticate] : true

        folder = if folder
          if folder.to_s =~ /^[\w_]+$/
            "a(#{folder})"
          else
            raise ArgumentError, "Voicemail folder must be alphanumerical/underscore characters only!"
          end
        elsif folder == ''
          raise ArgumentError, "Folder name cannot be an empty String!"
        else
          nil
        end

        real_mailbox = ""
        real_mailbox << "#{mailbox}"  unless mailbox.blank?
        real_mailbox << "@#{context}" unless context.blank?

        real_options = ""
        real_options << "s" if !authenticate
        real_options << folder unless folder.blank?

        command_args = [real_mailbox]
        command_args << real_options unless real_options.blank?
        command_args.clear if command_args == [""]

        execute 'VoiceMailMain', *command_args
      end

      #
      # Place a call in a queue to be answered by a registered agent. You must then call #join!
      #
      # @param [String] queue_name the queue name to place the caller in
      # @return [Adhearsion::Asterisk::QueueProxy] a queue proxy object
      #
      # @see http://www.voip-info.org/wiki-Asterisk+cmd+Queue Full information on the Asterisk Queue
      # @see Adhearsion::Asterisk":QueueProxy#join! for further details
      #
      def queue(queue_name)
        queue_name = queue_name.to_s

        @queue_proxy_hash_lock ||= Mutex.new
        @queue_proxy_hash_lock.synchronize do
          @queue_proxy_hash ||= {}
          if @queue_proxy_hash.has_key? queue_name
            return @queue_proxy_hash[queue_name]
          else
            proxy = @queue_proxy_hash[queue_name] = QueueProxy.new(queue_name, self)
            return proxy
          end
        end
      end

      # Plays the given Date, Time, or Integer (seconds since epoch)
      # using the given timezone and format.
      #
      # @param [Date|Time|DateTime] Time to be said.
      # @param [Hash] Additional options to specify how exactly to say time specified.
      #
      # +:timezone+ - Sends a timezone to asterisk. See /usr/share/zoneinfo for a list. Defaults to the machine timezone.
      # +:format+   - This is the format the time is to be said in.  Defaults to "ABdY 'digits/at' IMp"
      #
      # @see http://www.voip-info.org/wiki/view/Asterisk+cmd+SayUnixTime
      def play_time(*args)
        argument, options = args.flatten
        options ||= {}

        return false unless options.is_a? Hash

        timezone = options.delete(:timezone) || ''
        format   = options.delete(:format)   || ''
        epoch    = case argument
                   when Time || DateTime
                     argument.to_i
                   when Date
                     format = 'BdY' unless format.present?
                     argument.to_time.to_i
                   end

        return false if epoch.nil?

        execute "SayUnixTime", epoch, timezone, format
      end

      #Executes SayNumber with the passed argument.
      #
      # @param [Numeric|String] Numeric argument, or a string contanining numbers.
      def play_numeric(argument)
        execute "SayNumber", argument
      end

      #Executes SayDigits with the passed argument.
      #
      # @param [Numeric|String] Numeric argument, or a string contanining numbers.
      def play_digits(argument)
        execute "SayDigits", argument
      end

      #Executes Playtones with the passed argument.
      #
      # @param [String|Array] Array or comma-separated string of tones.
      # @param [Boolean] Whether to wait for the tones to finish (defaults to false).
      def play_tones(argument, wait = false)
        tones = [*argument].join(",")
        execute("Playtones", tones).tap do
          sleep tones.scan(/(?<=\/)\d+/).map(&:to_i).sum.to_f / 1000 if wait
        end
      end

      # Instruct Asterisk to play a sound file to the channel.
      #
      # @param [String] File name to play in the Asterisk convention, without extension.
      # @return [Boolean] Returns false if the argument could not be played.
      def play_soundfile(argument)
        execute "Playback", argument
        get_variable('PLAYBACKSTATUS') == PLAYBACK_SUCCESS
      end

      #
      # Generates silence in the background, just once until some other sound is generated, or
      # continuously for the duration of a given block. Silence is normally only generated under
      # specific circumstances but this method will explicitly generate it, which can be useful
      # in some scenarios.
      #
      # Note that the Playtones command must be available and the transmit_silence option must be
      # enabled in asterisk.conf. Also note that the given block is executed using instance_eval
      # and that imposes one important restriction. If the silence is interrupted outside the scope
      # of the block (e.g. calling play in another method) then it won't be restarted until
      # execution returns to the scope. However, it is safe to call generate_silence again when
      # outside the scope. Instance variables may be used as they are copied and copied back but be
      # careful handling immutable objects outside the scope. If you're unsure, don't use a block.
      #
      def generate_silence(&block)
        component = Punchblock::Component::Asterisk::AGI::Command.new :name => "EXEC Playtones", :params => ["0"]
        execute_component_and_await_completion component
        GenerateSilenceProxy.proxy_for(self, &block) if block_given?
      end

      class GenerateSilenceProxy
        def self.proxy_for(target, &block)
          proxy = new(target)
          ivs = target.instance_variables
          ivs.each { |iv| proxy.instance_variable_set iv, target.instance_variable_get(iv) }

          proxy.instance_eval(&block).tap do
            ivs = proxy.instance_variables - [:@_target]
            ivs.each { |iv| target.instance_variable_set iv, proxy.instance_variable_get(iv) }
          end
        end

        def initialize(target)
          @_target = target
        end

        def method_missing(*args)
          @_target.send(*args).tap do
            @_target.generate_silence
          end
        end
      end
    end
  end
end