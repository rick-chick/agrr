# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::MapArPersistenceErrorsTest < ActiveSupport::TestCase
  test "wraps StatementInvalid as PersistenceFailed with cause" do
    inner = ActiveRecord::StatementInvalid.new("bad sql")
    err = assert_raises(Domain::Shared::Exceptions::PersistenceFailed) do
      Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
        raise inner
      end
    end
    assert_includes err.message, "bad sql"
    assert_equal inner, err.cause
  end

  test "wraps ConnectionNotEstablished as PersistenceFailed with cause" do
    inner = ActiveRecord::ConnectionNotEstablished.new("no db")
    err = assert_raises(Domain::Shared::Exceptions::PersistenceFailed) do
      Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure do
        raise inner
      end
    end
    assert_includes err.message, "no db"
    assert_equal inner, err.cause
  end

  test "yield result is returned" do
    assert_equal :ok, Adapters::Shared::MapArPersistenceErrors.with_mapped_ar_persistence_failure { :ok }
  end
end
