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
  end
end
