require 'sinatra'
require 'sinatra/base'
require 'rest_client'
require 'json'
require "redis"
require "redis-namespace"
require "haml"
require 'net/http'
set :bind, '0.0.0.0'

get '/test_a' do
  puts 'get data '
end

post '/test_a' do
  puts 'post data'
end

get '/get_ip' do
  request.env['REMOTE_ADDR']
end

get '/hi' do
  puts 'remote_addr: ' + request.env['REMOTE_ADDR']
  access_token_url = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=wxf70039cdcb3bfde9&secret=e1df2788deff22154d8c0fa5c29c892d"
  ret = RestClient.get access_token_url
  m_token = JSON.parse(ret)["access_token"]
  {"error_code" => 0, "error_msg" => 'SUCCESS', "data" => {"token" => m_token}}.to_json
end

get '/index' do
  @rds = rds
  haml :index
end

get '/access_token' do
  access_token_url = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{rds.get(:appid)}&secret=#{rds.get(:secret)}"
  ret = RestClient.get access_token_url
  m_token = JSON.parse(ret)["access_token"]
  {"error_code" => 0, "error_msg" => 'SUCCESS', "data" => {"token" => m_token}}.to_json
end

post '/set_settings' do  
  rds.set(:url        , params["url"])
  rds.set(:appid      , params["appid"])  
  rds.set(:secret     , params["secret"])
  rds.set(:sso_secret , params["sso_secret"])
  rds.set(:openid     , params["openid"])
  rds.set(:email      , params["email"])
  rds.set(:number     , params["number"])
  @rds = rds
  redirect :index
end

post '/cls_msg' do
  rds.set(:rsp_body, '')
  redirect :index
end

post '/cls_push' do
  rds.set(:push_info, '')
  redirect :index
end

post '/send_msg' do
  content   = params["content"]
  number    = rds.get(:number)
  email     = rds.get(:email)
  timestamp = Time.now.strftime("%Y%m%d%H%M%S")
  query     = "number=#{number}&email=#{email}&timestamp=#{timestamp}"
  sign      = Digest::MD5.hexdigest(query + "&#{rds.get(:sso_secret)}").upcase

  xml = <<XML 
<xml>
<FromUserName><![CDATA[#{rds.get(:openid)}]]></FromUserName>
<Number><![CDATA[#{number}]]></Number>
<Email><![CDATA[#{email}]]></Email>
<Content><![CDATA[#{content}]]></Content>
<CreateTime><![CDATA[#{timestamp}]]></CreateTime>
<MsgType><![CDATA[text]]></MsgType>
<MsgId><![CDATA[#{timestamp}]]></MsgId>
</xml>
XML
  
  url      = rds.get(:url) + "?#{query}&sign=#{sign}"
  rsp_body = post_xml(url, xml)  
  msg = JSON.parse(rsp_body)['msg']

  raw      = rds.get(:rsp_body)  
  rsp_body = Time.now.strftime("%M:%S") +  (msg || '') + '&#13;&#10;' + (raw || '')
  rds.set(:rsp_body, rsp_body)
  @rds     = rds  
  redirect :index
end

post '/rcv' do  
  #puts request.body.read
  #puts request.body
  #puts params
  @request_payload = JSON.parse request.body.read
  puts @request_payload  

  rds.set(:push_info, @request_payload)
  if @request_payload
    msg     = @request_payload["msg"]
    kw_msg  = @request_payload["kw_msg"]
    if msg      
      to_user = msg["touser"]
      msgtype = msg["msgtype"]
      content = msg["text"]["content"]
      to_save = {to: to_user, type: msgtype, content: content, kw_msg: kw_msg }.to_s + '&#13;&#10;' + (rds.get(:push_info) || '').to_s
      #rds.set(:push_info, to_save)
    end
  end
end

def post_xml(url_string, xml_string)
  uri = URI(url_string)
  request = Net::HTTP::Post.new uri
  request.body = xml_string
  request.content_type = 'text/xml'
  response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }  
  response.body
end

def rds
  return $test_redis if $test_redis
  remote_redis = Redis.new(:host => 'localhost', :port => 6379, :db => 0)
  $test_redis = Redis::Namespace.new(:test_bigv_redis, :redis=> remote_redis)
end
