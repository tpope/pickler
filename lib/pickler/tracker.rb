require 'date'
require 'cgi'
require 'crack/xml'

class Pickler
  class Tracker

    ADDRESS = 'www.pivotaltracker.com'
    BASE_PATH = '/services/v3'
    SEARCH_KEYS = %w(label type state requester owner mywork id includedone)

    class Error < Pickler::Error; end

    attr_reader :token

    def initialize(token, ssl = false)
      @token = token
      @ssl = ssl
    end

    def ssl?
      @ssl
    end

    def http
      unless defined?(@http)
        if ssl?
          require 'net/https'
          @http = Net::HTTP.new(ADDRESS, Net::HTTP.https_default_port)
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          @http.use_ssl = true
        else
          require 'net/http'
          @http = Net::HTTP.new(ADDRESS)
        end
      end
      @http
    end

    def request(method, path, *args)
      headers = {
        "X-TrackerToken" => @token,
        "Accept"         => "application/xml",
        "Content-type"   => "application/xml"
      }
      http # trigger require of 'net/http'
      klass = Net::HTTP.const_get(method.to_s.capitalize)
      http.request(klass.new("#{BASE_PATH}#{path}", headers), *args)
    end

    def request_xml(method, path, *args)
      response = request(method,path,*args)
      raise response.inspect if response["Content-type"].split(/; */).first != "application/xml"
      hash = Crack::XML.parse(response.body)
      if hash["message"] && (response.code.to_i >= 400 || hash["success"] == "false")
        raise Error, hash["message"], caller
      end
      hash
    end

    def get_xml(path)
      request_xml(:get, path)
    end

    def project(id)
      Project.new(self, lambda { get_xml("/projects/#{id}")["project"] }, id)
    end

    class Abstract
      attr_reader :attributes

      def initialize(attributes = {})
        @attributes = {}
        (attributes || {}).each do |k,v|
          if respond_to?("#{k}=")
            send("#{k}=", v)
          else
            @attributes[k.to_s] = v
          end
        end
        yield self if block_given?
      end

      def self.reader(*methods)
        methods.each do |method|
          define_method(method) { attributes[method.to_s] }
        end
      end

      def self.date_reader(*methods)
        methods.each do |method|
          define_method(method) do
            value = attributes[method.to_s]
            value.kind_of?(String) ? Date.parse(value) : value
          end
        end
      end

      def self.accessor(*methods)
        reader(*methods)
        methods.each do |method|
          define_method("#{method}=") { |v| attributes[method.to_s] = v }
        end
      end

      def id
        id = attributes['id'] and Integer(id)
      end

      def to_xml
        Pickler.hash_to_xml(self.class.name.split('::').last.downcase, attributes)
      end

    end

  end
end

require 'pickler/tracker/project'
require 'pickler/tracker/story'
require 'pickler/tracker/iteration'
require 'pickler/tracker/note'
