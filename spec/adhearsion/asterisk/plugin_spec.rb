require 'spec_helper'

module Adhearsion::Asterisk
  describe 'plugin loading' do
    before(:all) { Adhearsion::Plugin.init_plugins }

    let(:mock_call) { double(:call).as_null_object }

    it 'should extend Adhearsion::CallController with Asterisk methods' do
      Adhearsion::CallController.new(mock_call).should respond_to :play_time
    end
  end
end
