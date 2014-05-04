class Pathname

  def touch
    require 'fileutils'
    FileUtils.touch(@path)
    self
  end

  def ==(other)
    other and @path == other.to_s
  end

end
