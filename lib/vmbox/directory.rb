class VMBox::Directory

  attr_accessor :box, :path

  def initialize(box, path)
    @box, @path = box, path
  end

  delegate :ssh, :scp, :to => :box

  def quoted_path
    "'#{path}'"
  end

  def exist?
    ssh("test -d #{quoted_path} && echo -n true") == "true"
  end

  def remove
    ssh "rm -rf #{quoted_path}"
  end

end
