require 'spec_helper'

describe VMBox::Storage do

  subject(:storage) { VMBox::Storage.new %w{storage1 storage2} }

  describe "#format" do
    subject { storage.format }

    context "when files have qcow extension" do
      before { storage.files = %w{storage1.qcow2 storage2.qcow2} }

      it { should eq(:qcow2) }
    end

    context "when files have no extension" do
      before { storage.files = %w{storage1 storage2} }

      it { should eq(:raw) }
    end
  end

  describe "#rollbackable?" do
    subject { storage.rollbackable? }

    context "when format is qcow2" do
      before { storage.stub :format => :qcow2 }

      it { should be_true }
    end

    context "when format is raw" do
      before { storage.stub :format => :raw }

      it { should be_false }
    end

  end

  describe "rollbackable" do

    context "when storage is rollbackable" do
      before { storage.stub :rollbackable? => true }

      it "should return itself" do
        storage.rollbackable.should == storage
      end
    end

    context "when storage isn't rollbackable" do
      before { storage.stub :rollbackable? => false }

      let!(:storage_converted_in_qcow2) do
        double.tap do |mock|
          storage.stub(:convert).with(:qcow2).and_return(mock)
        end
      end

      it "should convert itselft in qcow2 format" do
        storage.rollbackable.should == storage_converted_in_qcow2
      end
    end

  end

  describe "#convert" do

    context "when specified format isn't current format" do

      let(:target_format) { :dummy }

      before do
        storage.files = %w{storage1 storage2}
      end

      let!(:qemu_images) do
        storage.files.map do |file|
          double("QEMU image for #{file}")
        end.tap do |qemu_images|
          storage.stub :qemu_images => qemu_images
        end
      end

      it "should convert files" do
        storage.qemu_images.each do |qemu_image|
          qemu_image.should_receive(:convert).with(target_format).and_return("converted file name")
        end
        storage.convert target_format
      end

      it "should return a new Storage with converted files" do
        converted_files = storage.qemu_images.map do |qemu_image|
          "converted file of #{qemu_image}".tap do |converted_file|
            qemu_image.stub :convert => converted_file
          end
        end
        storage.convert(target_format).files.should == converted_files
      end

    end

    context "when specified format is current format" do

      let(:target_format) { storage.format }

      it "should return the Storage itself" do
        storage.convert(target_format).should == storage
      end

    end

  end

  describe "#qemu_images" do

    let(:options) { { :format => :dummy } }

    subject { storage.qemu_images options }

    it "should return a QEMU::Image for each storage file" do
      subject.map(&:file).should == storage.files
    end

    it "should use specified options" do
      subject.each do |qemu_image|
        qemu_image.format.should == options[:format]
      end
    end

  end

  describe "#exists?" do

    subject { storage.exists? }

    context "when every storage file exists" do
      before { File.stub :exists? => true }

      it { should be_true }
    end

    context "when a file is missing" do
      before { File.stub(:exists?).with(storage.files.first).and_return(false) }

      it { should be_false }
    end

  end

  describe "#create" do

    let(:qemu_images) { [ double(:create => true, :file => "dummy") ] }

    it "should use Storage format" do
      storage.stub :format => :dummy

      storage.should_receive(:qemu_images) do |options|
        options[:format].should == :dummy
        qemu_images
      end

      storage.create "1G"
    end

    it "should use specified size as image size" do
      size = "1G"

      storage.should_receive(:qemu_images) do |options|
        options[:size].should == size
        qemu_images
      end

      storage.create size
    end

    it "should define qemu options when qcow2 format is used" do
      storage.stub :format => :qcow2

      storage.should_receive(:qemu_images) do |options|
        options[:options].should == { :preallocation => "metadata", :cluster_size => "2M" }
        qemu_images
      end

      storage.create "1G"
    end

  end

  describe ".default" do

    it "should return a Storage with 'storage' file in given directory" do
      described_class.default("/tmp").files.map(&:to_s).should == %w{/tmp/storage}
    end

  end

  describe ".detect" do

    let(:directory) { "/path/to" }

    context "when StorageDectector find a existing Storage" do
      let(:detected_storage) { double }

      it "should return this existing Storage" do
        VMBox::StorageDetector.should_receive(:detect).with(directory).and_return detected_storage
         described_class.detect(directory).should == detected_storage
      end
    end

    context "when StorageDectector doesn't find a Storage" do
      before { VMBox::StorageDetector.stub :detect }

      it "should return the default Storage" do
        described_class.detect(directory).should == described_class.default(directory)
      end
    end

  end

end
