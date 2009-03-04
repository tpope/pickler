require 'date'
require 'cgi'

class Pickler
  class Tracker

    ADDRESS = 'www.pivotaltracker.com'
    BASE_PATH = '/services/v1'
    SEARCH_KEYS = %w(label type state requester owner mywork id includedone)

    class Error < Pickler::Error; end

    attr_reader :token

    def initialize(token, ssl = false)
      require 'active_support'
      @token = token
      @ssl = ssl
    end

    def ssl?
      @ssl
    end

    def http
      unless @http
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
      Hash.from_xml(response.body)["response"]
    end

    def get_xml(path)
      response = request_xml(:get, path)
      unless response["success"] == "true"
        if response["message"]
          raise Error, response["message"], caller
        else
          raise "#{path}: #{response.inspect}"
        end
      end
      response
    end

    def project(id)
      Project.new(self,get_xml("/projects/#{id}")["project"].merge("id" => id.to_i))
    end

    class Abstract
      def initialize(attributes = {})
        @attributes = {}
        (attributes || {}).each do |k,v|
          @attributes[k.to_s] = v
        end
        yield self if block_given?
      end

      def self.reader(*methods)
        methods.each do |method|
          define_method(method) { @attributes[method.to_s] }
        end
      end

      def self.date_reader(*methods)
        methods.each do |method|
          define_method(method) { value = @attributes[method.to_s] and Date.parse(value) }
        end
      end

      def self.accessor(*methods)
        reader(*methods)
        methods.each do |method|
          define_method("#{method}=") { |v| @attributes[method.to_s] = v }
        end
      end

      def id
        id = @attributes['id'] and Integer(id)
      end

      def to_xml(options = nil)
        @attributes.to_xml({:dasherize => false, :root => self.class.name.split('::').last.downcase}.merge(options||{}))
      end

    end

  end
end

require 'pickler/tracker/project'
require 'pickler/tracker/story'
require 'pickler/tracker/iteration'
require 'pickler/tracker/note'
