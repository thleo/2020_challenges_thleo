-- item_downloads
-- ~~~
-- Field name	Type	Mode	Description
-- id	INTEGER	NULLABLE
-- item_id	INTEGER	NULLABLE
-- user_id	INTEGER	NULLABLE
-- created_at	STRING	NULLABLE

-- item_properties
-- ~~~
-- Field name	Type	Mode	Description
-- id	INTEGER	NULLABLE
-- item_id	INTEGER	NULLABLE
-- modified_at	STRING	NULLABLE
-- description	STRING	NULLABLE
-- price	STRING	NULLABLE


-- items
-- ***
-- Field name	Type	Mode	Description
-- item_id	INTEGER	NULLABLE
-- test_item	BOOLEAN	NULLABLE
-- created_at	STRING	NULLABLE
-- resource_type	INTEGER	NULLABLE
-- category_grade	STRING	NULLABLE
-- seller_id	INTEGER	NULLABLE


-- DIM_ITEM
with item_properties_latest as (
  select
    item_id
    , description
    , price
    , modified_at
    , rank() over (partition by item_id order by modified_at) as recency
  from `tpt-interview-data-warehouse.sample.item_properties`
)
select a.item_id
  , a.test_item
  , a.created_at as item_created_at
  , b.modified_at as item_properties_modified_at
  , b.price
  , a.resource_type
  , case
      when a.resource_type = 1 then 'PDF'
      when a.resource_type = 2 then 'Video'
      when a.resource_type = 3 then 'Google Doc'
      else 'undefined'
    end as resource_type_desc
  , b.description as item_properties_description
  , a.seller_id
  , split(a.category_grade, '|')[offset(0)] as category
  , split(a.category_grade, '|')[offset(1)] as grade
from `tpt-interview-data-warehouse.sample.items` a
left join item_properties_latest b on a.item_id = b.item_id
where recency = 1

-- FACT_ITEM_DOWNLOADS
with item_properties_latest as (
  select
    item_id
    , description
    , price
    , modified_at
    , rank() over (partition by item_id order by modified_at) as recency
  from `tpt-interview-data-warehouse.sample.item_properties`
),
dim_item as (select a.item_id
  , a.test_item
  , a.created_at as item_created_at
  , b.modified_at as item_properties_modified_at
  , b.price
  , a.resource_type
  , case
      when a.resource_type = 1 then 'PDF'
      when a.resource_type = 2 then 'Video'
      when a.resource_type = 3 then 'Google Doc'
      else 'undefined'
    end as resource_type_desc
  , b.description as item_properties_description
  , a.seller_id
  , split(a.category_grade, '|')[offset(0)] as category
  , split(a.category_grade, '|')[offset(1)] as grade
from `tpt-interview-data-warehouse.sample.items` a
left join item_properties_latest b on a.item_id = b.item_id
where recency = 1
)
select distinct
  d.id as download_id
  , d.user_id
  , d.created_at as download_recorded_at
  , di.item_id
  , di.item_created_at
  , di.item_properties_modified_at
  , di.price
  , di.resource_type_desc
  , di.seller_id
  , di.category
  , di.grade

from dim_item di
left join item_downloads d on di.item_id = d.item_id
