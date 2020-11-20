
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
