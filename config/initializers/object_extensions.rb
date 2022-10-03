class Float
  def drop_decimal
    (self.to_s.scan(/[.]\d+/)[0].to_f > 0) ? self : self.to_i
  end
end