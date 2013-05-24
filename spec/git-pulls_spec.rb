require 'minitest/spec'
require 'minitest/autorun'
require 'git-pulls'

describe GitPulls do

  before do
    @gitpulls = GitPulls.new ['test']
  end

  describe "when getting user/proj from url" do

    it "should return user/proj on github.com" do
      @gitpulls.github_user_and_proj('https://github.com/user/proj.git').must_equal ['user','proj']
      @gitpulls.github_user_and_proj('https://github.com/user/proj').must_equal ['user','proj']
    end

    it "should return user/proj on enterprise when git-ssh" do
      @gitpulls.github_user_and_proj('git@github.hq.corp.lan:SomeGroup/some_repo.git').must_equal ['SomeGroup','some_repo']
      @gitpulls.github_user_and_proj('git@github.hq.corp.lan:SomeGroup/some_repo').must_equal ['SomeGroup','some_repo']
    end

    it "should return user/proj on enterprise when https" do
      @gitpulls.github_user_and_proj('https://github.hq.corp.lan/SomeGroup/some_repo.git').must_equal ['SomeGroup','some_repo']
      @gitpulls.github_user_and_proj('https://github.hq.corp.lan/SomeGroup/some_repo').must_equal ['SomeGroup','some_repo']
    end

    it "should return user/proj on enterprise when http" do
      @gitpulls.github_user_and_proj('http://github.hq.corp.lan/SomeGroup/some_repo.git').must_equal ['SomeGroup','some_repo']
    end
  end
end
