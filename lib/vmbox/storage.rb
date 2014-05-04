class VMBox::Storage

  attr_accessor :files

  def initialize(files = [])
    self.files = files
  end

  def files=(files)
    @files = Array(files).map { |file| Pathname.new(file) }
  end

  def each(&block)
    files.each &block
  end
  include Enumerable

  def ==(other)
    other and files == other.files
  end

  def create(size, options = {})
    options[:size] = size

    options[:format] = format
    options[:options] = {
      :preallocation => "metadata",
      :cluster_size => "2M"
    } if format == :qcow2

    VMBox.logger.info "Prepare storage #{options.inspect}"

    qemu_images(options).each do |qemu_image|
      # FIXME Use QEMU::Image#exists? when available
      qemu_image.create unless File.exists? qemu_image.file
    end
  end

  def qemu_images(options = {})
    map do |file|
      QEMU::Image.new file, options
    end
  end

  def exists?
    all? { |file| File.exists? file }
  end

  def convert(format)
    return self if self.format == format

    converted_files = qemu_images.map do |image|
      image.convert format
    end
    VMBox::Storage.new converted_files
  end

  def format
    extnames = map(&:extname).uniq
    if extnames.one?
      common_extname = extnames.first
      common_extname.empty? ? :raw : common_extname.gsub(/^\./,"").to_sym
    else
      raise "Files used several formats : #{extnames}"
    end
  end

  def rollbackable?
    format == :qcow2
  end

  def rollbackable
    rollbackable? ? self : convert(:qcow2)
  end

  def self.detect(directory)
    VMBox::StorageDetector.detect(directory) or default(directory)
  end

  def self.default(directory)
    VMBox::Storage.new Pathname.new(directory).join('storage')
  end

end
