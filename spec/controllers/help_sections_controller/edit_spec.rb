require 'spec_helper'

describe HelpSectionsController, '#edit' do

  integrate_views

  let(:help_section) { Factory.create(:help_section) }
  let(:admin_user) { Factory.create(:user, :admin => true) }
  let(:valid_params) { { :id => help_section.id } }

  before(:each) { login_as(admin_user) }

  it 'renders the "edit" template' do
    get(:edit, valid_params)
    response.should render_template('help_sections/edit')
  end

end
