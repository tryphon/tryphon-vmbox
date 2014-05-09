class VMBox::File

  attr_accessor :box, :path

  def initialize(box, path)
    @box, @path = box, path
  end

  delegate :ssh, :scp, :to => :box

  def quoted_path
    "'#{path}'"
  end

  def touch
    ssh "touch #{quoted_path}"
  end

  def exist?
    ssh("test -f #{quoted_path} && echo -n true") == "true"
  end

  def remove
    ssh "rm #{quoted_path}"
  end

  def read
    scp do |scp|
      scp.download! path
    end
  end

  def write(content)
    scp do |scp|
      scp.upload! StringIO.new(content), path
    end
  end

  def open(&block)
    Tempfile.open('vmbox_file') do |f|
      f.close
      scp do |scp|
        scp.download! path, f.path
      end
      yield f.path
    end
  end

end
