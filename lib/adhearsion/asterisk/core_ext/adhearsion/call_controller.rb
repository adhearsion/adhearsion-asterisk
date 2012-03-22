module Adhearsion

  ##
  # Monkeypatches to Adhearsion for Asterisk-specific functionality.
  #
  class CallController
    #
    # Plays a single output, not only files, accepting interruption by one of the digits specified
    # Currently still stops execution, will be fixed soon in Punchblock
    #
    # @param [Object] String or Hash specifying output and options
    # @param [String] String with the digits that are allowed to interrupt output
    # @return [String|nil] The pressed digit, or nil if nothing was pressed
    #
    def stream_file(argument, digits = '0123456789#*')
      begin
        output_component = ::Punchblock::Component::Asterisk::AGI::Command.new :name => "STREAM FILE",
                                                                               :params => [
                                                                                 argument,
                                                                                 digits
                                                                               ]
        execute_component_and_await_completion output_component

        reason = output_component.complete_event.reason

        case reason.result
        when 0
          raise CallController::Output::PlaybackError if reason.data == "endpos=0"
          nil
        when -1
          raise CallController::Output::PlaybackError
        else
          [reason.result].pack 'U*'
        end
      rescue StandardError => e
        raise CallController::Output::PlaybackError, "Output failed for argument #{argument.inspect}"
      end
    end
  end
end
