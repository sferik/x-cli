class String
  def prepend_at
    "@#{self}"
  end

  def strip_ats
    tr("@", "")
  end

  alias old_to_i to_i

  def to_i(base = 10)
    tr(",", "").old_to_i(base)
  end
end
