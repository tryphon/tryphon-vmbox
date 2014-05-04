require 'spec_helper'

describe VMBox::StorageDetector do

  let(:directory) { Pathname.new("tmp/storage") }

  subject(:detector) { VMBox::StorageDetector.new(directory) }

  def clean_directory
    directory.rmtree if directory.exist?
    directory.mkpath
  end

  before { clean_directory }
  after { clean_directory }

  def create_files(*names)
    names.map do |name|
      directory.join(name).tap do |file|
        file.touch
      end
    end
  end

  RSpec::Matchers.define :detect do |description, *names|
    match do |detector|
      files = create_files(*names)
      detector.detect.files == files
    end
  end

  it { should detect "single storage file", "storage" }
  it { should detect "single storage qcow file", "storage.qcow2" }

  it { should detect "two storage files", "storage1", "storage2" }
  it { should detect "two storage qcow files", "storage1.qcow2", "storage2.qcow2" }

  context "when a single qcow file exists" do
    before { create_files "storage.qcow2" }
    it { should detect "single storage file", "storage" }
  end

end
