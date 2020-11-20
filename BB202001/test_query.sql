-- generate tables

CREATE TABLE rebill
    ("id" int, "customer_id" int, "created_at" timestamp, "cancellation_date" timestamp)
;

INSERT INTO rebill
    ("id", "customer_id", "created_at", "cancellation_date")
VALUES
    (1, 1, '2018-01-01 15:47:15', '2018-11-15 09:31:57'),
    (2, 2, '2018-07-05 08:45:23', NULL),
    (3, 1, '2019-02-27 14:56:37', NULL),
    (4, 3, '2020-01-01 00:00:00', NULL)
;


CREATE TABLE gift
    ("id" int, "customer_id" int, "num_months" int, "created_at" timestamp)
;

INSERT INTO gift
    ("id", "customer_id", "num_months", "created_at")
VALUES
    (1, 4, 3, '2019-12-26 12:46:55'),
    (2, 3, 6, '2019-06-01 13:14:13'),
    (3, 2, 3, '2018-12-01 09:59:01'),
    (4, 5, 12, '2020-01-02 01:15:15')
;

-- get all first sub type
with all_subs as (
  select customer_id
    , created_at
    , type
  from (select customer_id, created_at, 'self' as type from rebill) rs
  union all (select customer_id, created_at, 'gift' as type from gift)
),
ranked as (
  select distinct
    customer_id
    , created_at
    , type
    , rank() over (partition by customer_id order by created_at) sub_rank
  from all_subs
  order by customer_id, sub_rank
)
select distinct
  customer_id
  , created_at
  , type
from ranked
where sub_rank=1

-- determine cust type
with all_subs as (
  select sub_id
    , customer_id
    , created_at
    , type
  from (select id||'s' as sub_id, customer_id, created_at, 'self' as type from rebill) rs
  union all (select id||'g' as sub_id, customer_id, created_at, 'gift' as type from gift)
),
sub_totals as(
  select distinct
    customer_id
    , count(distinct case when type='self' then sub_id else null end) as total_self
    , count(distinct case when type='gift' then sub_id else null end) as total_gift
  from all_subs
  group by 1
)
select distinct
  customer_id
  , total_self
  , total_gift
  , case when total_self > 0 then 'self' else 'gift' end as type_cust
from sub_totals

-- combined query
-- Analysis Answer

with all_subs as (
  select sub_id
    , customer_id
    , created_at
    , type
  from (select id||'s' as sub_id, customer_id, created_at, 'self' as type from rebill) rs
  union all (select id||'g' as sub_id, customer_id, created_at, 'gift' as type from gift)
),
ranked as (
  select distinct
    customer_id
    , created_at
    , type
    , rank() over (partition by customer_id order by created_at) sub_rank
  from all_subs
  order by customer_id, sub_rank
),
sub_totals as(
  select distinct
    customer_id
    , count(distinct case when type='self' then sub_id else null end) as total_self
    , count(distinct case when type='gift' then sub_id else null end) as total_gift
  from all_subs
  group by 1
),
cust_facts as (
  select distinct
    customer_id
    , case when total_self > 0 then 'self' else 'gift' end as type_cust
  from sub_totals
)
select distinct
  r.customer_id
  , created_at as first_subscribed_at
  , type as first_subscription_type
  , type_cust as customer_group
from ranked r
left join cust_facts cf on r.customer_id=cf.customer_id
where sub_rank=1
