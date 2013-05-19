require 'spec_helper'

describe VMBox do

  subject { VMBox.new "test" }

  describe "#system" do
    
    it "should be 'dist/disk' by default" do
      subject.system.to_s.should == "dist/disk"
    end

  end
  
end
