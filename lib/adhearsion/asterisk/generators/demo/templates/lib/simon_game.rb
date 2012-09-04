class SimonGame < Adhearsion::CallController
  def run
    answer
    reset
    loop do
      update_number
      collect_attempt
      verify_attempt
    end
  end

  def random_number
    rand(10).to_s
  end

  def update_number
    @number << random_number
  end

  def collect_attempt
    play_digits "#{@number}"
    result = ask :limit => @number.length
    @attempt = result.response
  end

  def verify_attempt
    if attempt_correct?
      play sound_path('good')
    else
      play_numeric "#{@number.length}"
      play sound_path('times')
      play sound_path('wrong-try-again-smarty')
      reset
    end
  end

  def attempt_correct?
    @attempt == @number
  end

  def reset
    @attempt, @number = '', ''
  end

  def sound_path(file)
    File.join("#{Adhearsion.config.platform[:root]}", "sounds", file)
  end
end  
