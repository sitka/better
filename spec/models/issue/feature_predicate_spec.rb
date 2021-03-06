require 'spec_helper'

describe Issue, '#feature?' do

  let(:issue) { Issue.new }

  context 'when tracker is feature' do
    it 'returns true' do
      issue.stub(:tracker).and_return(mock(:feature? => true))
      issue.feature?.should be true
    end
  end

  context 'when tracker is not feature' do
    it 'returns false' do
      issue.stub(:tracker).and_return(mock(:feature? => false))
      issue.feature?.should be false
    end
  end
end
