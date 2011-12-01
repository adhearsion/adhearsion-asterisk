module Adhearsion
  module Asterisk
    PLAYBACK_SUCCESS = 'SUCCESS' unless defined? PLAYBACK_SUCCESS

    class Plugin < Adhearsion::Plugin
      dialplan :agi do |name, *params|
        component = Punchblock::Component::Asterisk::AGI::Command.new :name => name, :params => params
        execute_component_and_await_completion component
        complete_reason = component.complete_event.resource.reason
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
      dialplan :execute do |name, *params|
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
      dialplan :verbose do |message, level = nil|
        agi 'VERBOSE', message, level
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
      dialplan :get_variable do |variable_name|
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
      dialplan :set_variable do |variable_name, value|
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
      dialplan :sip_add_header do |header, value|
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
      dialplan :sip_get_header do |header|
        get_variable "SIP_HEADER(#{header})"
      end

      #
      # Allows you to either set or get a channel variable from Asterisk.
      # The method takes a hash key/value pair if you would like to set a variable
      # Or a single string with the variable to get from Asterisk
      #
      dialplan :variable do |*args|
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
      dialplan :meetme do |conference_id, options = {}|
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
      dialplan :voicemail do |*args|
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
      dialplan :voicemail_main do |options = {}|
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
      dialplan :queue do |queue_name|
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

      # Plays the specified sound file names. This method will handle Time/DateTime objects (e.g. Time.now),
      # Fixnums (e.g. 1000), Strings which are valid Fixnums (e.g "123"), and direct sound files. When playing
      # numbers, Adhearsion assumes you're saying the number, not the digits. For example, play("100")
      # is pronounced as "one hundred" instead of "one zero zero". To specify how the Date/Time objects are said
      # pass in as an array with the first parameter as the Date/Time/DateTime object along with a hash with the
      # additional options.  See play_time for more information.
      #
      # Note: it is not necessary to supply a sound file extension; Asterisk will try to find a sound
      # file encoded using the current channel's codec, if one exists. If not, it will transcode from
      # the default codec (GSM). Asterisk stores its sound files in /var/lib/asterisk/sounds.
      #
      # @example Play file hello-world.???
      #   play 'hello-world'
      # @example Speak current time
      #   play Time.now
      # @example Speak today's date
      #   play Date.today
      # @example Speak today's date in a specific format
      #   play [Date.today, {:format => 'BdY'}]
      # @example Play sound file, speak number, play two more sound files
      #   play %w"a-connect-charge-of 22 cents-per-minute will-apply"
      # @example Play two sound files
      #   play "you-sound-cute", "what-are-you-wearing"
      #
      # @return [Boolean] true is returned if everything was successful.  Otherwise, false indicates that
      #   some sound file(s) could not be played.
      dialplan :play do |*arguments|
        begin
          play! arguments
        rescue Adhearsion::PlaybackError => e
          return false
        end
        true
      end

      # Same as {#play}, but immediately raises an exception if a sound file cannot be played.
      #
      # @return [true]
      # @raise [Adhearsion::VoIP::PlaybackError] If a sound file cannot be played
      dialplan :play! do |*arguments|
        result = true
        unless play_time(arguments)
          arguments.flatten.each do |argument|
            result &= play_numeric(argument) || play_soundfile(argument)
          end
        end
        raise Adhearsion::PlaybackError if !result
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
      dialplan :play_time do |*args|
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
      # @return [Boolean] Returns false if the argument could not be played.
      dialplan :play_numeric do |argument|
        if argument.kind_of?(Numeric) || argument =~ /^\d+$/
          execute "SayNumber", argument
        end
      end

      # Instruct Asterisk to play a sound file to the channel.
      #
      # @param [String] File name to play in the Asterisk convention, without extension.
      # @return [Boolean] Returns false if the argument could not be played.
      dialplan :play_soundfile do |argument|
        execute "Playback", argument
        get_variable('PLAYBACKSTATUS') == PLAYBACK_SUCCESS
      end

    end#class
  end#module
end#module
