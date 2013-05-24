require "vmbox/version"
require "qemu"
require "open-uri"
require "json"

class Object

  def try(method, *args)
    send method, *args unless nil?
  end

end

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

  def ip_address
    @ip_address ||= ArpScan.new(:tap0).host(:mac_address => mac_address).try :ip_address
  end

  class ArpScan < Struct.new(:interface)

    def output
      `sudo arp-scan --localnet --interface #{interface}`
    end

    def hosts
      output.scan(/^([0-9\.]+)\t([0-9a-f:]+)\t(.*)$/).map do |host_line|
        Host.new(*host_line)
      end
    end

    def host(filters = {})
      hosts.find do |host|
        filters.all? do |k,v|
          host.send(k) == v
        end
      end
    end

    class Host < Struct.new(:ip_address, :mac_address, :vendor)

      def ==(other)
        [:ip_address, :mac_address, :vendor].all? do |attribute|
          other.respond_to? attribute and send(attribute) == other.send(attribute)
        end
      end

    end

  end

  attr_accessor :mac_address
  def mac_address
    @mac_address ||= "52:54:00:12:35:0#{index}"
  end

  def url(path)
    "http://#{ip_address or hostname}/#{path}"
  end

  def status
    JSON.parse open(url("status.json")).read if ip_address
  rescue
    nil
  end

  attr_accessor :system
  attr_accessor :storage

  def up?
    # Because ip_address uses arp-scan
    !!ip_address
  end

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
