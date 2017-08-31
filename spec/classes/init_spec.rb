require 'spec_helper'
describe 'networkconf' do
  context 'with default values for all parameters' do
    it { should contain_class('networkconf') }
  end
end
