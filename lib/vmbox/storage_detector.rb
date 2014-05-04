class VMBox::StorageDetector

  def self.detect(directory)
    new(directory).detect
  end

  @@layout_candidates = [
    'storage',
    'storage.qcow2',
    %w{storage1 storage2},
    %w{storage1.qcow2 storage2.qcow2},
  ]
  cattr_accessor :layout_candidates

  attr_accessor :directory

  def initialize(directory)
    self.directory = directory
  end

  def directory=(directory)
    @directory = Pathname.new(directory)
  end

  def layouts
    @layouts ||= layout_candidates.map do |candidates|
      Layout.new files(candidates)
    end
  end

  def files(names)
    Array(names).map do |name|
      directory.join name
    end
  end

  def preferred_layout
    layouts.find &:exists?
  end

  def detect
    preferred_layout.try :storage
  end

  class Layout

    attr_accessor :candidates

    def initialize(candidates)
      self.candidates = candidates
    end

    def candidates=(candidates)
      @candidates = Array(candidates)
    end

    def existing_files
      @existing_files ||= candidates.select do |file|
        File.exists? file
      end
    end

    def exists?
      not existing_files.empty?
    end

    def storage
      VMBox::Storage.new existing_files
    end

  end

end
