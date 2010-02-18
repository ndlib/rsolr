# A module that defines the interface and top-level logic for http based connection classes.
module RSolr::Connection::Requestable
  
  include RSolr::Connection::Utils
  
  attr_reader :opts, :uri, :proxy
  
  # opts can have:
  #   :url => 'http://localhost:8080/solr'
  def initialize opts={}
    opts[:url] ||= 'http://127.0.0.1:8983/solr'
    @opts = opts
    @uri = URI.parse opts[:url]
    @proxy = URI.parse opts[:proxy] if opts[:proxy]
  end
  
  # send a request to the connection
  # request '/select', :q=>'*:*'
  #
  # request '/update', {:wt=>:xml}, '</commit>'
  # 
  # force a post where the post body is the param query
  # request '/update', "<optimize/>", :method=>:post
  #
  def request path, params={}, *extra
    # be nice
    extra = extra.dup
    opts = extra[-1].kind_of?(Hash) ? extra.pop : {}
    data = extra[0]
    context = create_request_context path, params, data
    
    if opts[:method] == :post
      raise "Don't send POST data when using :method => :post" unless data.to_s.empty?
      # force a POST, use the query string as the POST body
      context.merge! :data => hash_to_query(params), :headers => {'Content-Type' => 'application/x-www-form-urlencoded'}
    elsif data
      # standard POST, using "data" as the POST body
      context.merge! :headers => {'Content-Type' => 'text/xml; charset=utf-8'}
    end
    
    error = nil
    response = {}
    begin
      response = context[:data] ? self.post(context[:url], context[:data], context[:headers]) : self.get(context[:url])
    rescue
      error = $!.to_s
    end
    
    error = (response[:message].inspect || "Solr Error") unless response[:status_code] == 200
    
    raise RSolr::RequestError.new("#{error} -> #{context.inspect}") if error
    
    context.merge response
  end
  
  def create_request_context path, params, data
    url = build_url path, params
    full_url = prepend_base url
    context = {:path => path, :url => full_url, :params => params, :query => hash_to_query(params), :data => data}
  end
  
  # accepts a path/string and optional hash of query params
  def build_url path, params={}
    full_path = @uri.path + path
    super full_path, params, @uri.query
  end
  
  def prepend_base url
    full_url = "#{@uri.scheme}://#{@uri.host}"
    full_url += @uri.port ? ":#{@uri.port}" : ''
    full_url += url
  end
  
end