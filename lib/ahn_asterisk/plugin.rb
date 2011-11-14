module AhnAsterisk
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
  end
end
