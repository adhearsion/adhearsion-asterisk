module Adhearsion
  module Asterisk
    module HasAgiContext
     def agi_context
       self[:x_agi_context]
     end
    end

    class Adhearsion::Call
      include HasAgiContext
    end
  end
end
