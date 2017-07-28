<img src="https://raw.githubusercontent.com/full360/sneaql/master/sneaql.jpg" alt="sneaql raccoon" width="800">

# SneaQL AWS Extensions

Enhanced SneaQL with AWS interactions

## Purpose

To enable provide additional SneaQL command tags for interacting with Amazon Web Services.

## Installing

sneaql-aws depends upon sneaql.

```
gem install sneaql-aws
```

## Command: AWS_S3_OBJECT_LIST

**description:**

searches an S3 bucket and brings back a list of available objects based upon the object prefix. the object list is stored as a sneaql recordset which can be iterated or used with other recordset operations.

**parameters:**

* required - recordset name to store search results
* required - bucket name to search
* required - AWS region containing the bucket
* required - prefix to match object keys

**behavior:**

* all s3 objects with an object key (file name) matching the prefix provided will be returned and stored as a recordset.
* provide AWS credentials either through environment variables or with an instance role
* note that large result sets can eat up memory on your sneaql server

**examples:**

the example below will create a table, and populate it with your search results. large result sets will generate a high number of insert statements which may be prohibitive on your RDBMS. we are working on a way to enable export of recordsets to s3.


```
/*-execute-*/
drop table if exists s3_records cascade;

/*-execute-*/
create table if not exists s3_records
(
  keyname varchar(512),
  last_modified timestamp,
  etag varchar(255),
  size bigint,
  storage_class varchar(32),
  owner_name varchar(255),
  owner_id varchar(255)
)

/*-aws_s3_object_list s3records 'your-s3-bucket-name' 'us-west-2' 'example/' -*/

/*-iterate s3records-*/
insert into s3_records values
(
  ':s3records.key',
  ':s3records.last_modified'::timestamp,
  ':s3records.etag',
  ':s3records.size',
  ':s3records.storage_class',
  ':s3records.owner_name',
  ':s3records.owner_id'
);
```