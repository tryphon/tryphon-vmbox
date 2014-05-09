class VMBox::Configuration

  attr_accessor :box

  def initialize(box)
    @box = box
  end

  def puppet_configuration
    @puppet_configuration ||= Box::PuppetConfiguration.new
  end
  delegate :[], :[]=, :fetch, :push, :delete, :to => :puppet_configuration

  def configuration_file
    box.file puppet_configuration.configuration_file
  end

  def load
    configuration_file.open do |file|
      puppet_configuration.clear
      puppet_configuration.load file
    end
    self
  end

  def save
    Tempfile.open('vmbox_configuration') do |f|
      f.close
      puppet_configuration.save f.path

      configuration_file.write File.read(f.path)
    end
  end

  def deploy!
    box.ssh puppet_configuration.deploy_command
  end

  def persist!
    box.ssh puppet_configuration.persist_command
  end

end
