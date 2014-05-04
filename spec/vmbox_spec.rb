require 'spec_helper'

describe VMBox do

  subject { VMBox.new "test" }

  describe "#system" do

    it "should be 'dist/disk' by default" do
      subject.system.to_s.should == "dist/disk"
    end

  end

  describe "#ip_address" do

    let(:arp_scan) do
      double.tap do |arp_scan|
        VMBox::ArpScan.should_receive(:new).and_return(arp_scan)
      end
    end

    it "should find VM ip with arp-scan" do
      arp_scan.should_receive(:host).with(:mac_address => subject.mac_address).and_return(double(:ip_address => "dummy"))
      subject.ip_address.should == "dummy"
    end

  end

  describe "up?" do

    it "should return true if ip_address is present" do
      subject.stub :ip_address => "dummy"
      subject.should be_up
    end

    it "should return false if ip_address is nil" do
      subject.stub :ip_address => nil
      subject.should_not be_up
    end

  end

  describe "#url" do

    it "should use ip_address if available" do
      subject.stub :ip_address => "1.2.3.4"
      subject.url("dummy").should == "http://1.2.3.4/dummy"
    end

    it "should use hostname if ip_address is nil" do
      subject.stub :ip_address => nil, :hostname => "hostname"
      subject.url("dummy").should == "http://hostname/dummy"
    end

  end

  describe "#mac_address" do

    it "should use index to build a default mac_address" do
      subject.index = 1
      subject.mac_address.should == "52:54:00:12:35:01"
    end

  end

  describe "#storage" do

    let(:storage) { double }

    it "should detect storage in root_dir" do
      VMBox::Storage.should_receive(:detect).with(subject.root_dir).and_return(storage)
      subject.storage.should == storage
    end

  end

end
