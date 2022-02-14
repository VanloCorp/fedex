require 'fedex/request/base'
require 'fedex/ground_manifest'

module Fedex
  module Request
    class GroundClose < Base

      attr_reader :up_to_time, :references, :filename

      def initialize(credentials, options={})
        # requires!(options, :up_to_time)

        @credentials = credentials
        # it's either up_to_time or references
        @up_to_time = options[:up_to_time]
        @references = options[:references]

        @filename = options[:filename]
        @debug = ENV['DEBUG'] == 'true'
      end

      def process_request
        puts build_xml if @debug == true
        api_response = self.class.post(api_url, :body => build_xml)
        puts api_response.body.encode!('UTF-8', undef: :replace) if @debug == true
        response = parse_response(api_response)
        if success?(response)
          success_response(response)
        else
          error_message = if response[:ground_close_reply]
            [response[:ground_close_reply][:notifications]].flatten.first[:message]
          else
            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n
            --#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
          end rescue $1
          raise RateError, error_message
        end
      end

      private

      def success_response(response)
        manifest_details = {
          :filename => filename,
          :manifest => response[:ground_close_reply][:manifest]
        }
        manifest = Fedex::GroundManifest.new(manifest_details)
        puts "manifest written to #{filename}" if @debug == true
        manifest
      end

      # Build xml Fedex Web Service request
      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          #xml.CloseWithDocumentsRequest(:xmlns => "http://fedex.com/ws/close/v5"){
          xml.GroundCloseRequest(:xmlns => "http://fedex.com/ws/close/v5"){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)

            if references
              xml.CloseGrouping('MANIFEST_REFERENCE')
              references.each do |value|
                xml.ManifestReferenceDetail {
                  xml.Type('CUSTOMER_REFERENCE')
                  xml.Value(value)
                }
              end
            elsif up_to_time
              xml.TimeUpToWhichShipmentsAreToBeClosed(up_to_time.utc.iso8601.chop)
            end

            #xml.ActionType('CLOSE')
            #xml.CarrierCode('FDXE')
            # xml.ProcessingOptions {
            #   xml.Options('ERROR_IF_OPEN_SHIPMENTS_FOUND')
            # }
            # xml.CloseDocumentSpecification {
            #   xml.CloseDocumentTypes('MANIFEST')
            # }
          }
        end
        builder.doc.root.to_xml
      end

      def service
        { :id => 'clos', :version => '5' }
      end

      # Successful request
      def success?(response)
        response[:ground_close_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:ground_close_reply][:highest_severity])
      end
    end
  end
end
