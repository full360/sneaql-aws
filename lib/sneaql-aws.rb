require 'sneaql'
require 'aws-sdk'

# AWS extensions for SneaQL
module SneaqlAWS
  # Command tags providing AWS functionalities to SneaQL
  module Commands
    # runs the query then stores the array of hashes into the recordset hash
    class SneaqlAWSS3ObjectList < Sneaql::Core::SneaqlCommand
      Sneaql::Core::RegisterMappedClass.new(
        :command,
        'aws_s3_object_list',
        SneaqlAWS::Commands::SneaqlAWSS3ObjectList
      )

      # @param [String] recordset_name name of the recordset in which to store the results
      def action(recordset_name, bucket_name, bucket_region, object_prefix)
        r = s3_object_search(
          bucket_name,
          bucket_region,
          object_prefix
        )
        
        @logger.debug("adding #{r.length} recs as #{recordset_name}")
        @recordset_manager.store_recordset(recordset_name, r)
      end

      # argument types
      def arg_definition
        [:recordset, :expression, :expression, :expression]
      end
      
      # @return [Array] returns array of hashes from SQL results
      def s3_object_search(bucket, region, prefix)
        bucket = @expression_handler.evaluate_expression(bucket)
        region = @expression_handler.evaluate_expression(region)
        prefix = @expression_handler.evaluate_expression(prefix)
        
        @logger.debug("creating s3 connection...")
        # create connection to s3
        # aws credentials will be resolved through normal SDK precedence rules
        s3 = Aws::S3::Resource.new(region: region)
        
        @logger.info("searching for objects in bucket #{bucket} in region #{region} matching prefix #{prefix}")
        # perform the initial object search
        resp = s3.client.list_objects_v2(
          {
            bucket: bucket,
            prefix: prefix,
            fetch_owner: true
          }
        )
        
        # array to hold results
        res = []
        
        # response contents are converted to native ruby hashes
        # then appended to the res array for use as a recordset 
        resp['contents'].each do |obj|
          res << {
            key: obj.key,
            last_modified: obj.last_modified.to_s,
            etag: obj.etag,
            size: obj.size,
            storage_class: obj.storage_class,
            owner_name: obj.owner['display_name'],
            owner_id: obj.owner['id']
          }
        end
        
        # check to see if there is a continuation token
        next_token = resp.next_continuation_token
        
        # repeat until all results have been gathered
        while next_token do
          resp = s3.client.list_objects_v2(
            {
              bucket: bucket,
              continuation_token: next_token
            }
          )
          
          resp['contents'].each do |obj|
            res << {
              key: obj.key,
              last_modified: obj.last_modified.to_s,
              etag: obj.etag,
              size: obj.size,
              storage_class: obj.storage_class,
              owner_name: obj.owner['display_name'],
              owner_id: obj.owner['id']
            }
          end
          
          next_token = resp.next_continuation_token
        end
        
        @logger.info("#{res.length} objects found")
        return res
      end
    end
  end
end