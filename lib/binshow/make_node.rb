module Binshow
  def self.make_magic(offset, str)
    str = str.dup.freeze if !str.frozen?
    {
      offset: offset,
      length: str.bytesize,
      type: :magic,
      value: str,
      children: [],
    }
  end
end
