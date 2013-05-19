require "vmbox/version"
require "qemu"
require "open-uri"
require "json"

class VMBox

  attr_accessor :name

  def initialize(name, options = {})
    @name = name
    options.each { |k,v| send "#{k}=", v }
  end

  attr_accessor :index

  def index
    @index ||= 0
  end

  @@root_dir = Pathname.new("dist")
  def root_dir
    @@root_dir
  end
  def self.root_dir=(root_dir)
    @@root_dir = Pathname.new(root_dir)
  end

  def rollbackable
    @rollbackable ||= dup.tap do |other|
      other.system = QEMU::Image.new(system).convert(:qcow2)
    end
  end

  def start_and_save
    rollbackable.start
    wait_for(100) { status }
    save
  end

  def wait_for(limit = 30, &block)
    time_limit = Time.now + limit
    begin
      sleep limit / 20
      raise "Timeout" if Time.now > time_limit 
    end until yield
  end

  def hostname
    "#{name}.local"
  end

  def status
    JSON.parse open("http://#{hostname}/status.json").read 
  rescue 
    nil
  end

  attr_accessor :system
  attr_accessor :storage

  def system
    @system ||=  root_dir + "disk"
  end

  def storage
    @storage ||= root_dir + "storage"
  end

  def storage?
    File.exists?(storage)
  end

  def kvm
    @kvm ||= QEMU::Command.new.tap do |kvm|
      kvm.name = name
      kvm.memory = 800 # tmpfs to small with 512
      kvm.disks.add(system, :cache => :unsafe)
      kvm.disks << storage if storage?

      # TODO support index > 9 ...
      kvm.mac_address = "52:54:00:12:35:0#{index}"

      kvm.telnet_port = telnet_port
      kvm.vnc = ":#{index}"
      
      kvm.sound_hardware = "ac97"
    end
  end

  def telnet_port
    4444 + index
  end

  def prepare(origin_system, storage_size = nil)
    prepare_storage storage_size unless storage_size.nil? or File.exists?(storage)
  end

  # TODO support raid
  def prepare_storage(storage_size)
    QEMU::Image.new(storage, :size => storage_size).create
  end

  def start
    kvm.daemon.start
  end

  def stop
    kvm.daemon.stop
  end

  def reset
    kvm.qemu_monitor.reset
  end

  def save
    kvm.qemu_monitor.savevm
  end

  def rollback
    kvm.qemu_monitor.loadvm
  end

end

