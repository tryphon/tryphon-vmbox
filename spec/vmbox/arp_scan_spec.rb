require 'spec_helper'

describe VMBox::ArpScan do

  let(:arp_scan_output) { File.read(File.expand_path("../../fixtures/arp_scan_output.txt", __FILE__)) }

  subject { VMBox::ArpScan.new :dummy0 }

  describe "#hosts" do

    before do
      subject.stub :output => arp_scan_output
    end

    it "should return hosts described by arp-scan output" do
      subject.hosts.should include(VMBox::ArpScan::Host.new("10.164.13.241","64:27:23:4f:27:0d","Dummy"))
    end

  end

  describe "#host" do

    let(:host) { VMBox::ArpScan::Host.new("10.164.13.241","64:27:23:4f:27:0d","Dummy") }

    before do
      subject.stub :hosts => [host]
    end

    it "should find host by mac_address" do
      subject.host(:mac_address => host.mac_address).should == host
    end

    it "should find host by ip_address" do
      subject.host(:ip_address => host.ip_address).should == host
    end

  end

end
