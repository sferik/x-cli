module Kernel
  def Bignum(arg, base = 0) # rubocop:disable Naming/MethodName
    Integer(arg, base)
  end

  def Fixnum(arg, base = 0) # rubocop:disable Naming/MethodName
    Integer(arg, base)
  end

  def NilClass(_) # rubocop:disable Naming/MethodName
    nil
  end
end
