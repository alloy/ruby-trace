class X
  def initialize
    @y = Y.new
  end

  def y
    @y.call1(self)
    @y.call2(self)
    nil
  end

  def call1
    :call1
  end

  def call2
    :call2
  end
end
