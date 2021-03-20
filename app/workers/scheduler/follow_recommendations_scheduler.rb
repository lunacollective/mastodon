# frozen_string_literal: true

class Scheduler::FollowRecommendationsScheduler
  include Sidekiq::Worker
  include Redisable

  sidekiq_options retry: 0

  def perform
    fallback_recommendations = FollowRecommendation.safe.filtered.limit(100)

    I18n.available_locales.each do |locale|
      recommendations = []

      # We can skip the work if no accounts with that language exist
      recommendations.concat(FollowRecommendation.safe.filtered.localized(locale).limit(100)) if AccountSummary.safe.filtered.localized(locale).exists?

      # Use language-agnostic results if there are not enough language-specific ones
      recommendations.concat(fallback_recommendations.take(100 - recommendations.size)) if recommendations.size < 100

      redis.pipelined do
        redis.del(key(locale))

        recommendations.each do |recommendation|
          redis.zadd(key(locale), recommendation.rank, recommendation.account_id)
        end
      end
    end
  end

  private

  def key(locale)
    "follow_recommendations:#{locale}"
  end
end
