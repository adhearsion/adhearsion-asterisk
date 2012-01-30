module Adhearsion

  ##
  # Monkeypatches to Adhearsion for Asterisk-specific functionality.
  #
  class CallController
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
    def play(*arguments)
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
    def play!(*arguments)
      result = true
      unless play_time(arguments)
        arguments.flatten.each do |argument|
          result &= play_numeric(argument) || play_soundfile(argument)
        end
      end
      raise Adhearsion::PlaybackError if !result
    end

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
          raise Adhearsion::PlaybackError if reason.data == "endpos=0"
          nil
        when -1
          raise Adhearsion::PlaybackError
        else
          [reason.result].pack 'U*'
        end
      rescue StandardError => e
        raise Adhearsion::PlaybackError, "Output failed for argument #{argument.inspect}"
      end
    end
  end
end
