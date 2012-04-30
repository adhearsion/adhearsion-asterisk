require 'adhearsion'
require 'active_support/dependencies/autoload'
require 'adhearsion/asterisk/version'
require 'adhearsion/asterisk/call_controller_methods'
require 'adhearsion/asterisk/has_agi_context'
require 'adhearsion/asterisk/plugin'

module Adhearsion
  module Asterisk
    extend ActiveSupport::Autoload

    autoload :QueueProxy

    #
    # Execute an AMI action synchronously
    #
    # @param [String] name the name of the action to execute
    # @param [Hash<String => Object>] options options to pass to the action
    #
    # @yield [Punchblock::Event::Asterisk::AMI::Event] block to handle each event resulting from the action
    #
    # @return [Punchblock::Event::Complete] action complete event
    #
    # @example Execute a CoreShowChannels action, handling each channel event:
    #
    #   Adhearsion::Asterisk.execute_ami_action('CoreShowChannels') { |channel| puts channel.inspect }
    #
    def self.execute_ami_action(name, options = {}, &block)
      component = Punchblock::Component::Asterisk::AMI::Action.new :name => name, :params => options
      component.register_event_handler(Punchblock::Event::Asterisk::AMI::Event, &block) if block
      Adhearsion::PunchblockPlugin.execute_component component
      component.complete_event
    end
  end
end
