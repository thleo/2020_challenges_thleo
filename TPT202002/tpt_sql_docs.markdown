## Model Documentation
This document is broken into 2 major parts, one part per model generated.

The select statements are written for operation in the BigQuery IDE; if they were
written as models then the second query would not have to encompass the query written
for `dim_item`.

#### Assumptions and thoughts
- `item_downloads.created_at` is approximately time of sale
- for building the `FACT_ITEM_DOWNLOADS` table we are focusing on download quantity of particular
items and their volume of download
  - the best practice would be to create several separate tables that allow us to see:
    - the latest item price
    - the price at time of purchase
      - if there was an intermediate table that always showed the latest price and was updated
      daily then the latest price could be attached to the download at time of sale
        - eg: `last_price`, a table with the fields `latest_price`,
        `latest_price_start`,`previous_price`, `previous_price_start`; if the time of sale
        (`item_downloads.created_at`) falls after the `latest_price_start` value, then the latest
        price is attached to the download id, and if the time of sale falls after
        `latest_price_start` and after `previous_price_start` then `previous_price` is used
          - the logic for backfilling data with greater than 1 price chance is a bit more complex

      - for accurately tracking revenue generated over time, or impact of pricing changes on sales
  - for simplicity's sake this table is omitted; if such a table were to be created, it would be a
  `item_sale_facts` table and would be useful to augment a `seller_mart` as well as highlight
  trends in price changes vs volume of sales
    - additionally, this table would be good to integrate with a payments table to determine
    popular methods of payment and weighing pro's and con's of one payment service vs another
- assume that `id` in any table is a unique primary key
- assume that the relation between `item_properties` and `items` is many to one
  - there is only a single entry per item which is generated at its time of creation,
  but the properties of the item can be updated over time

### `dim_item`
``` sql
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
```

Above is the entire query; the explanation will be broken into parts discussing the query from top to bottom.

For generating the dimension table it is important to indicate the latest properties; the
uniqueness of the rows here will be based on the `items` table so only the latest properties will
be used in order to prevent a fanout for items that have multiple rows in `item_properties`

The CTE `item_properties_latest` ranks the entries in `item_properties` so that we can
use only the latest entries for each item.

The aliases `item_created_at` and `item_properties_modified_at` are used to provide a clarity to anyone looking to revise the model code by indicating **source_field** for each column in the `select` statement.

A `case when` is used to create easy to read/filter fields when doing QA downstream or providing reporting. The `undefined` tag serves to aid manual QA for undefined/new resource types.

The `select` statement omits `category_grade` as it has been split out into two separate strings.


## `fact_item_downloads`

```sql
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
```

This query adds on to the one above; the differences are the added join to `item_downloads` and the columns in the select statement.

Some useful metrics one may wish to aggregate are:
- total downloads
- daily downloads over a lookback period
- popularity of resource based on age

All of the above metrics can be determined by doing some variation of a `count (distinct id)`.

These metrics informed what other attributes to pull in
- user_id
  - this can be used to look at the trends of a specific user, or when combined with user data, it can be used to search for trends among cohorts
- download_recorded_at
  - this can be used to determine seasonality for optimizing sales and ad spend
- item_id
  - looking at the top sellers for recommendations and for building recommendations engines when combined with user profiles
- item_created_at
  - for determining the age of an item and seeing if there are certain types of resources that only sell for a certain period of time after they are created -- that is, how long a resource is considered relevant to the community
- item_properties_modified_at
- price
  - this can be used to look at trends among different price bins and help with building user personas
- resource_type_desc
  - popularity of resource types
- seller_id
  - tracking trends with sellers; if there's a large account this could be useful for the customer success team to be aware of
- category
  - this can aid in determining where certain resources are lacking and target user growth in those areas to create a well rounded platform
  - desired growth areas can also be determined by comparing category downloads against how many resources are being generated for this category
- grade
  - useful for breaking out resources by grade level
