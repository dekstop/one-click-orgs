require 'spec_helper'

module ProposalsSpecHelper
  def a_proposal_exists
    Proposal.destroy_all
    login
    post(proposals_path, {:proposal => {:id => nil, :proposer_member_id => Member.first.id, :title => 'proposal'}})
    @proposal = Proposal.first
  end
end

describe "everything" do
  include ProposalsSpecHelper
  
  before(:each) do 
    stub_organisation!
    stub_constitution!
    default_user
    set_permission(default_user, :vote, true)
    login
  end
  
  describe "/proposals/1, given a proposal exists" do
    before(:each) do
      @member_two = Member.make
      set_permission(@member_two, :vote, true)
      @member_three = Member.make
      set_permission(@member_two, :vote, true)
      
      a_proposal_exists
    end
    
    describe "GET" do
      before(:each) do
        @proposal = Proposal.first
        default_user.cast_vote(:for, @proposal.id)
        @member_two.cast_vote(:for, @proposal.id)
        @member_three.cast_vote(:against, @proposal.id)

        get(proposal_path(@proposal))
      end
  
      it "responds successfully" do
        @response.should be_successful
      end
      
      it "should display the correct vote count" do
        response.should contain /2\s*\/\s*1/ # i.e. "2/1" with arbitrary whitespace
      end
    end
  end
  
  describe "/proposals, given a proposal exists"  do
    before(:each) do
      a_proposal_exists
    end
    
     describe "GET" do
       before(:each) do
         get(proposals_path)
       end

       it "responds successfully" do
         @response.should be_successful
       end

       it "contains a list of proposals" do
         # pending
         @response.should have_xpath("//ul")
       end
     end
  end
  
  describe "proposing text amendments" do
    before(:each) do
      login
      @proposal = mock('proposal', :save => true)
    end
    
    it "should create a proposal to change the organisation name" do
      ChangeTextProposal.should_receive(:serialize_parameters).with(
        'name' => 'organisation_name',
        'value' => 'The Yoghurt Yurt'
      ).and_return(@serialized_parameters = mock('serialized_parameters'))
      
      ChangeTextProposal.should_receive(:new).with(
        :title => "Change organisation name to 'The Yoghurt Yurt'",
        :parameters => @serialized_parameters,
        :proposer_member_id => @user.id
      ).and_return(@proposal)
      
      post(url_for(:controller => 'proposals', :action => 'create_text_amendment'), {'name' => 'organisation_name', 'value' => 'The Yoghurt Yurt'})

      @response.should redirect_to('/one_click/control_centre')
    end
    
    it "should create a proposal to change the objectives" do
      ChangeTextProposal.should_receive(:serialize_parameters).with(
        'name' => 'objectives',
        'value' => 'make all the yoghurt'
      ).and_return(@serialized_parameters = mock('serialized_parameters'))
      
      ChangeTextProposal.should_receive(:new).with(
        :title => "Change objectives to 'make all the yoghurt'",
        :parameters => @serialized_parameters,
        :proposer_member_id => @user.id
      ).and_return(@proposal)
      
      post(url_for(:controller => 'proposals', :action => 'create_text_amendment'), {'name' => 'objectives', 'value' => 'make all the yoghurt'})
      
      @response.should redirect_to('/one_click/control_centre')
    end
    
    it "should create a proposal to change the domain" do
      ChangeTextProposal.should_receive(:serialize_parameters).with(
        'name' => 'domain',
        'value' => 'yaourt.com'
      ).and_return(@serialized_parameters = mock('serialized_parameters'))
      
      ChangeTextProposal.should_receive(:new).with(
        :title => "Change domain to 'yaourt.com'",
        :parameters => @serialized_parameters,
        :proposer_member_id => @user.id
      ).and_return(@proposal)
      
      post(url_for(:controller => 'proposals', :action => 'create_text_amendment'), {'name' => 'domain', 'value' => 'yaourt.com'})
      
      @response.should redirect_to('/one_click/control_centre')
    end
  end
  
  describe "proposing voting system amendments" do
    before do
      login
      @general_voting_system = Clause.set_text('general_voting_system', 'RelativeMajority')
      @membership_voting_system = Clause.set_text('membership_voting_system', 'RelativeMajority')
      @constitution_voting_system = Clause.set_text('constitution_voting_system', 'RelativeMajority')
    end
    
    describe "for general decisions" do
      it "should add the proposal" do
        post(url_for(:controller => 'proposals', :action => 'create_voting_system_amendment'), {:general_voting_system => 'Unanimous'})

        puts @response.body if @response.status != 302

        @response.should redirect_to("/one_click/control_centre")
      
        ChangeVotingSystemProposal.count.should == 1
        ChangeVotingSystemProposal.first.title.should == 'change general voting system to Supporting votes from every single member'
        proposal_parameters = ActiveSupport::JSON.decode(ChangeVotingSystemProposal.all.first.parameters)
        proposal_parameters['type'].should == 'general'
        proposal_parameters['proposed_system'].should == 'Unanimous'
      end
    end
    
    describe "for membership decisions" do
      it "should add the proposal" do
        post(url_for(:controller=>'proposals', :action=>'create_voting_system_amendment'), {:membership_voting_system=>'Veto'})

        puts @response.body if @response.status != 302

        @response.should redirect_to("/one_click/control_centre")
      
        ChangeVotingSystemProposal.count.should == 1
        ChangeVotingSystemProposal.all.first.title.should == 'change membership voting system to No opposing votes'
        proposal_parameters = ActiveSupport::JSON.decode(ChangeVotingSystemProposal.all.first.parameters)
        proposal_parameters['type'].should == 'membership'
        proposal_parameters['proposed_system'].should == 'Veto'
      end
    end
    
    describe "for constitution decisions" do
      it "should add the proposal" do
        post(url_for(:controller=>'proposals', :action=>'create_voting_system_amendment'), {:constitution_voting_system=>'AbsoluteMajority'})

        puts @response.body if @response.status == 500
        @response.should redirect_to("/one_click/control_centre")
      
        ChangeVotingSystemProposal.count.should == 1
        ChangeVotingSystemProposal.all.first.title.should == 'change constitution voting system to Supporting votes from more than half the members'
        proposal_parameters = ActiveSupport::JSON.decode(ChangeVotingSystemProposal.all.first.parameters)
        proposal_parameters['type'].should == 'constitution'
        proposal_parameters['proposed_system'].should == 'AbsoluteMajority'
      end
    end
    
    describe "voting period amendments" do
      it "should add the proposal" do
        post(url_for(:controller=>'proposals', :action=>'create_voting_period_amendment'), {:new_voting_period=>'86400'})

        puts @response.body if @response.status == 500
        @response.should redirect_to("/one_click/control_centre")

        ChangeVotingPeriodProposal.count.should == 1
        ChangeVotingPeriodProposal.all.first.title.should == 'Change voting period to 24 hours'
        proposal_parameters = ActiveSupport::JSON.decode(ChangeVotingPeriodProposal.all.first.parameters)
        proposal_parameters['new_voting_period'].to_i.should == 86400
      end
    end
  end
end

