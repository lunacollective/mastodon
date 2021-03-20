# frozen_string_literal: true

class PotentialFriendshipTracker
  EXPIRE_AFTER = 90.days.seconds
  MAX_ITEMS    = 80

  WEIGHTS = {
    reply: 1,
    favourite: 10,
    reblog: 20,
  }.freeze

  class << self
    include Redisable

    def record(account_id, target_account_id, action)
      return if account_id == target_account_id

      key    = "interactions:#{account_id}"
      weight = WEIGHTS[action]

      redis.zincrby(key, weight, target_account_id)
      redis.zremrangebyrank(key, 0, -MAX_ITEMS)
      redis.expire(key, EXPIRE_AFTER)
    end

    def remove(account_id, target_account_id)
      redis.zrem("interactions:#{account_id}", target_account_id)
    end

    def get(account, limit: 20, offset: 0)
      account_ids          = redis.zrevrange("interactions:#{account.id}", offset, limit)
      fallback_account_ids = redis.zrevrange("follow_recommendations:#{account.user_locale}", 0, -1)

      [].tap do |accounts|
        accounts.concat(Account.searchable.where(id: account_ids)) unless account_ids.empty?
        accounts.concat(Account.followable_by(account).not_excluded_by_account(account).not_domain_blocked_by_account(account).where(id: fallback_account_ids).limit(limit - accounts.size)) if accounts.size < limit && offset.zero? && fallback_account_ids.size.positive?
      end
    end
  end
end
