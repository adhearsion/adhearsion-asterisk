require 'spec_helper'

describe Adhearsion::Asterisk do
  subject { Adhearsion::Asterisk }

  it "should be a module" do
    subject.should be_kind_of Module
  end
end
