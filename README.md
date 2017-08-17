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

## AWS Credentials

AWS credentials are handled with the same precedence as the ruby SDK. If an IAM role is applied to your instance or container, you do not need to provide access keys.

Note that you do need to provide the AWS region to most of the sneaql command tags. You can set and use an environment variable `AWS_REGION=us-west-2` then reference this region in your sneaql command tag `:env_AWS_REGION`.

## Enabling SneaQL Extensions

SneaQL extensions are installed on your system as a rubygem, but the sneaql binary disables them by default. In order to enable this (or any) sneaql extension, you need to set the following environment variable as shown:

```
SNEAQL_EXTENSIONS=sneaql-aws
```

Note that you can enable multiple extensions by providing a comma delimited list to the `SNEAQL_EXTENSIONS` variable.

## Command: AWS\_S3\_OBJECT_LIST

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

## Command: AWS\_RECORDSET\_TO_S3

**description:**

dumps the contents of a sneaql recordset into a file in S3. there are several formatting options available. the `json` and `gzipjson` formats are useful for easy loading into Amazon Redshift via the `copy` command with the `json(auto)` options.

**parameters:**

* required - recordset name to dump
* required - target bucket name
* required - AWS region containing the bucket
* required - S3 object key (path in S3)
* required - object type.. current available values are `json` and `gzipjson`

**behavior:**

* data is dumped into a local file in the specified format, then pushed to S3
* **NOTE** this is not intended to be used to dump large amounts of data... as recordsets must fit in memory!

**examples:**

the example below creates a recordset from a sql query, then pushes the recordset to S3 as a gzipped json file:


```
/*-recordset column_definitions -*/
select * from pg_table_def;

/*-aws_recordset_to_s3 column_definitions 'my-bucket-name' 'us-west-2' 'dbdata/pg_table_def.json' gzipjson-*/
```