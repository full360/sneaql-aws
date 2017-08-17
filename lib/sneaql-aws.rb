require 'sneaql'
require 'aws-sdk'
require 'json'
require 'zlib'

# AWS extensions for SneaQL
module SneaqlAWS
  module Exceptions
    # Exception used to to gracefully exit test
    class AWSResourceCreationException < Sneaql::Exceptions::BaseError
      def initialize(msg = 'Unable to create AWS resource')
        super
      end
    end
    
    # Exception used to to gracefully exit test
    class AWSS3Exception < Sneaql::Exceptions::BaseError
      def initialize(msg = 'Error interacting with AWS S3 service')
        super
      end
    end
  end
  
  # Command tags providing AWS functionalities to SneaQL
  module Commands
    
    class AWSInteractions
      def initialize(logger)
        @logger = logger ? logger : Logger.new(STDOUT)  
      end
      
      def s3_resource(region)
        @logger.debug("creating S3 resource...")
        Aws::S3::Resource.new(region: region)
      rescue => e
        @logger.error(e.message)
        e.backtrace.each { |b| @logger.error(b) }
        raise SneaqlAWS::Exceptions::AWSResourceCreationException
      end

      def upload_to_s3(bucket_name, bucket_region, object_key, local_file_path)
        interactions = AWSInteractions.new(@logger)
        s3 = s3_resource(bucket_region)
        @logger.info("uploading local file #{local_file_path} to s3://#{bucket_name}/#{object_key}")
        s3 = Aws::S3::Resource.new(region: bucket_region)
        File.open(local_file_path, 'rb') do |file|
          s3.client.put_object(bucket: bucket_name, key: object_key, body: file)
        end
      rescue => e
        @logger.error(e.message)
        e.backtrace.each { |b| @logger.error(b) }
        raise SneaqlAWS::Exceptions::AWSS3Exception
      end
      
    end
    
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
        
        @recordset_manager.store_recordset(recordset_name, r)
        @logger.info("added #{r.length} records to recordset #{recordset_name}")
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

        # create connection to s3
        # aws credentials will be resolved through normal SDK precedence rules
        interactions = AWSInteractions.new(@logger)
        s3 = interactions.s3_resource(region)
        
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
            region: region,
            bucket: bucket,
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
              region: region,
              bucket: bucket,
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
    
    # writes a recordset to S3 in a gzip json format
    class SneaqlAWSRecordsetToS3 < Sneaql::Core::SneaqlCommand
      Sneaql::Core::RegisterMappedClass.new(
        :command,
        'aws_recordset_to_s3',
        SneaqlAWS::Commands::SneaqlAWSRecordsetToS3
      )

      def action(recordset_name, bucket, region, key, object_type)
        bucket_name = @expression_handler.evaluate_expression(bucket)
        bucket_region = @expression_handler.evaluate_expression(region)
        object_key = @expression_handler.evaluate_expression(key)
        
        recordset_to_file(
          recordset_name,
          local_json_path,
          object_type
        )
        
        interactions = AWSInteractions.new(@logger)
        interactions.upload_to_s3(
          bucket_name,
          bucket_region,
          object_key,
          local_json_path
        )
      end

      # argument types
      def arg_definition
        [:recordset, :expression, :expression, :expression, :symbol]
      end

      def local_json_path
        "/tmp/json_export_#{self.object_id}.gz"
      end

      def recordset_to_file(recordset, local_file_path, object_type)
        @logger.debug("writing recordset #{recordset} to file of type #{object_type}")
        
        if object_type == 'gzipjson'
          json_file = File.open(local_file_path, 'w')
          zd = Zlib::GzipWriter.new(json_file)

          json_gzip_streamer = Proc.new do |z, h|
            h.keys.each do |k|
              if h[k].class == Float
                h[k] = nil if (h[k].nan? or h[k].infinite?)
              end
            end
            z << (h.to_json + "\n") && z.write(z.flush)
          end
          
          @recordset_manager.recordset[recordset].each do |r|
            json_gzip_streamer.call(zd, r)
          end
          
          zd.close
          json_file.close
          
        elsif object_type == 'json'
          json_file = File.open(local_file_path, 'w')
          
          json_formatter = Proc.new do |f, h|
            h.keys.each do |k|
              if h[k].class == Float
                h[k] = nil if (h[k].nan? or h[k].infinite?)
              end
            end
            f.puts h.to_json
          end
          
          @recordset_manager.recordset[recordset].each do |r|
            json_formatter.call(json_file, r)
          end
          
          json_file.close
        end
        
        @logger.info("#{@recordset_manager.recordset[recordset].length} written for recordset #{recordset} ")
      end
      
    end
  end
end