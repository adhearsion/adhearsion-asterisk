require 'spec_helper'

module Adhearsion::Asterisk
  describe HasAgiContext do
    let(:offer) do
      Adhearsion::Event::Offer.new :headers => {:x_agi_context => 'foobar'}
    end

    subject { Adhearsion::Call.new offer}

    it "should return the AGI context" do
      subject.agi_context.should be == 'foobar'
    end
  end
end
