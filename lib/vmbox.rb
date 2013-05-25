require "vmbox/version"
require "qemu"
require "open-uri"
require "json"
require "logger"

require "active_support/core_ext/module/attribute_accessors"

class Object

  def try(method, *args)
    send method, *args unless nil?
  end

end

class VMBox

  @@logger = Logger.new("log/vmboxes.log")
  mattr_accessor :logger

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
  mattr_accessor :root_dir

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
    logger.info "Wait for VMBox status"
    wait_for(100) { up? and status }
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
      command = "sudo arp-scan --localnet --interface #{interface}"
      VMBox.logger.debug "Run arp-scan : #{command}"
      `#{command}`
    end

    def hosts
      output.scan(/^([0-9\.]+)\t([0-9a-f:]+)\t(.*)$/).map do |host_line|
        Host.new(*host_line)
      end.tap do |hosts|
        VMBox.logger.debug { "Found #{hosts.size} host(s) : #{hosts.map(&:ip_address).join(',')}" }
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
    status_url = url("status.json")
    logger.debug "Retrieve VMBox status (#{status_url})"
    JSON.parse open(status_url).read if ip_address
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

      logger.debug "Prepare KVM instance: #{kvm.inspect}"
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
    logger.info "Start VMBox #{name}"
    kvm.daemon.start
  end

  def stop
    logger.info "Stop VMBox #{name}"
    kvm.daemon.stop
  end

  def reset
    logger.info "Reset VMBox #{name}"
    kvm.qemu_monitor.reset
  end

  def save
    logger.info "Save VMBox #{name}"
    kvm.qemu_monitor.savevm
  end

  def rollback
    logger.info "Rollback VMBox #{name}"
    kvm.qemu_monitor.loadvm
  end

end
