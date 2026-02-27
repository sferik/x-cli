require "test_helper"

class TestCollectable < TTestCase
  def setup
    super
    @test_obj = Object.new
    @test_obj.extend(T::Collectable)
  end

  def test_collect_with_page_returns_a_set_when_block_yields_nil
    result = @test_obj.collect_with_page { |_page| nil }

    assert_kind_of(Set, result)
  end

  def test_collect_with_page_returns_empty_collection_when_block_yields_nil
    result = @test_obj.collect_with_page { |_page| nil }

    assert_empty(result)
  end
end
