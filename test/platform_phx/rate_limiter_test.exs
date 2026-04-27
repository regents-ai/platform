defmodule PlatformPhx.RateLimiterTest do
  use ExUnit.Case, async: false

  alias PlatformPhx.RateLimiter

  setup do
    RateLimiter.reset()
    :ok
  end

  test "allows requests up to the configured limit" do
    assert :ok = RateLimiter.check(:test_limit, "wallet", 2, 1_000)
    assert :ok = RateLimiter.check(:test_limit, "wallet", 2, 1_000)
    assert {:error, :limited} = RateLimiter.check(:test_limit, "wallet", 2, 1_000)
  end

  test "cleanup removes only expired buckets" do
    now = System.monotonic_time(:millisecond)
    expired_key = {:test_cleanup, "expired", 1}
    fresh_key = {:test_cleanup, "fresh", 1}

    true = :ets.insert(RateLimiter, {expired_key, 1, now - 1})
    true = :ets.insert(RateLimiter, {fresh_key, 1, now + 10_000})

    RateLimiter
    |> Process.whereis()
    |> send(:cleanup)

    _state = :sys.get_state(RateLimiter)

    assert [] = :ets.lookup(RateLimiter, expired_key)
    assert [{^fresh_key, 1, _expires_at}] = :ets.lookup(RateLimiter, fresh_key)
  end
end
