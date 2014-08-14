require "vmbox/version"
require "qemu"
require "open-uri"
require "json"
require "logger"
require 'net/ssh'
require 'net/scp'
require 'net/ftp'
require 'tempfile'
require 'box'

require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/class/attribute_accessors"
require 'active_support/core_ext/module/delegation'


class Object

  def try(method, *args)
    send method, *args unless nil?
  end

end

class VMBox

  @@logger = Logger.new("log/vmboxes.log")
  mattr_accessor :logger

  attr_accessor :name, :architecture

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
      logger.info "Convert system disk to qcow2"
      other.system = QEMU::Image.new(system).convert(:qcow2)
      other.storage = other.storage.rollbackable if storage.exists?
    end
  end

  def start_and_save(timeout = nil)
    timeout ||= 240

    rollbackable.start
    logger.info "Wait for VMBox ready?"
    wait_for(timeout) { ready? }
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

  attr_accessor :mac_address
  def mac_address
    @mac_address ||= ("52:54:00:12:35:%02d" % index)
  end

  def url(path = nil)
    "http://#{ip_address or hostname}/#{path}"
  end

  def status
    status_url = url("status.json")
    logger.debug "Retrieve VMBox status (#{status_url})"

    if up?
      raw_attributes = JSON.parse(open(status_url).read)
      Status.new(raw_attributes.merge(:ignored_details => ignored_status_details)).tap do |status|
        logger.debug "Current VMBox status : #{status.inspect}"
      end
    end
  rescue => e
    logger.debug "Can't return status : #{e}"
    nil
  end

  def ignored_status_details
    @ignored_status_details ||= []
  end

  class Status

    attr_accessor :global_status, :details, :ignored_details

    def initialize(attributes = {})
      attributes.each { |k,v| send "#{k}=", v }
    end

    def ready?
      ok? or signifiant_details.empty?
    end

    def ok?
      global_status == "ok"
    end

    def ignored_details
      @ignored_details ||= []
    end

    def ignored_detail?(detail_name)
      ignored_details.any? do |ignored_detail|
        ignored_detail.match detail_name
      end
    end

    def signifiant_details
      details.delete_if do |detail|
        ignored_detail? detail["name"]
      end
    end

  end

  def ready?
    up? and retrieved_status = status and retrieved_status.ready?
  end

  attr_accessor :system
  attr_accessor :storage

  def up?
    # Because ip_address uses arp-scan
    !!ip_address
  end

  def system
    @system ||=  root_dir.join "disk"
  end

  def storage
    @storage ||= VMBox::Storage.detect(root_dir)
  end

  def kvm
    @kvm ||= QEMU::Command.new.tap do |kvm|
      kvm.name = name
      kvm.architecture = architecture

      kvm.usb = true

      kvm.memory = 800 # tmpfs to small with 512
      kvm.disks.add system, :cache => :none

      storage.each do |file|
        kvm.disks.add file, :cache => :none
      end if storage.exists?

      kvm.mac_address = mac_address

      kvm.telnet_port = telnet_port
      kvm.vnc = ":#{index}"

      kvm.sound_hardware = "ac97"

      logger.debug "Prepare KVM instance: #{kvm.inspect}"
    end
  end

  delegate :qemu_monitor, :to => :kvm

  def telnet_port
    4444 + index
  end

  def prepare(origin_system, storage_size = nil)
    storage.create storage_size unless storage_size.nil? or storage.exists?
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

  def rollback(timeout = 240)
    logger.info "Rollback VMBox #{name}"
    kvm.qemu_monitor.loadvm
    logger.info "Wait for VMBox ready?"
    wait_for(timeout) { ready? }
  end

  def reboot(timeout = 240)
    logger.info "Reboot VMBox #{name}"
    ssh "reboot"
    logger.info "Wait for VMBox ready?"
    wait_for(timeout) { ready? }
  end

  def ssh(command = nil, &block)
    Net::SSH.start(ip_address, "root", :paranoid => false) do |ssh|
      if command
        logger.debug "Execute '#{command}'"
        ssh.exec! command
      else
        yield ssh
      end
    end
  end

  def scp(&block)
    result = nil
    Net::SCP.start(ip_address, "root", :paranoid => false) do |scp|
      result = yield scp
    end
    result
  end

  def ftp(&block)
    Net::FTP.open(ip_address) do |ftp|
      ftp.login
      yield ftp
    end
  end

  def file_cache
    @file_cache ||= Hash.new do |hash, path|
      hash[path] = VMBox::File.new self, path
    end
  end

  def file(path)
    file_cache[path]
  end

  def directory_cache
    @directory_cache ||= Hash.new do |hash, path|
      hash[path] = VMBox::Directory.new self, path
    end
  end

  def directory(path)
    directory_cache[path]
  end

  def configuration(&block)
    VMBox::Configuration.new(self).load.tap do |config|
      yield config if block_given?
    end
  end

end

QEMU.logger = Box.logger = VMBox.logger
Box::PuppetConfiguration.system_update_command = nil

require 'vmbox/storage'
require 'vmbox/storage_detector'
require 'vmbox/arp_scan'
require 'vmbox/file'
require 'vmbox/directory'
require 'vmbox/configuration'
