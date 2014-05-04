class VMBox::ArpScan < Struct.new(:interface)

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
