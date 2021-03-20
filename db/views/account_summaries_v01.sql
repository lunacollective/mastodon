SELECT
  accounts.id AS account_id,
  mode() WITHIN GROUP (ORDER BY language ASC) AS language,
  mode() WITHIN GROUP (ORDER BY sensitive ASC) AS sensitive
FROM accounts
CROSS JOIN LATERAL (
  SELECT
    statuses.account_id,
    statuses.language,
    statuses.sensitive
  FROM statuses
  WHERE statuses.account_id = accounts.id
    AND statuses.deleted_at IS NULL
  ORDER BY statuses.id DESC
  LIMIT 20
) t0
GROUP BY accounts.id
