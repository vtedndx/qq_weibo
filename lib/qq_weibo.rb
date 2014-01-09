require 'hashie'
require 'openssl'
require 'net/https'
require 'net/http'
require 'uri'
require 'json'
require 'cgi'
require "qq_weibo/version"

module QqWeibo
  #对腾讯微博返回的用户信息封装
  def self.merge_info(d)
    user_info = Hashie::Mash.new
    user_info.merge!({:user_id=>d["openid"]})
    user_info.merge!({:head_url=>d["head"] == "" ? "http://mat1.gtimg.com/www/mb/img/p1/head_normal_50.png" : "#{d["head"]}"})
    if !d["gender"].nil? && !d["gender"].blank?
      user_info.merge!({:sex=>d["gender"]=='m' ? 1 : 0})
    else
      user_info.merge!({:sex=>2})
    end
    user_info.merge!({:fans_number=>d["followers_count"]})
    user_info.merge!({:location =>d["location"]})
    user_info.merge!({:name=>d["name"]})
    user_info.merge!({:nick=>d["nick"]})
    user_info.merge!({:weburl=>"http://weibo.com/"})
    user_info.merge!({:verified_type=>d["isvip"]})
    return user_info
  end

  #取消关注
  def self.destroy_focus(appkey, appsecret, openid, openkey, fopenid)
    url = URI("http://open.t.qq.com/api/friends/del")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/user/info")}&#{URI.escape("fopenid=#{fopenid}&oauth_version=2.a&scope=all")}&#{appsecret}"
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({:appid => appkey, :format => "json", :fopenid => fopenid, :openid => openid, :openkey => openkey, :reqtime => Time.now.to_i, :sig => current_sig, :wbversion => 1})
    http.request(request).body
  end

  #关注
  def self.add_focus(appkey, appsecret, openid, openkey, fopenid)
    url = URI("http://open.t.qq.com/api/friends/add")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/friends/add")}&#{URI.escape("fopenids=#{fopenid}")}&#{appsecret}"
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({:appid => appkey, :format => "json", :fopenids => fopenid, :openid => openid, :openkey => openkey, :reqtime => Time.now.to_i, :sig => current_sig, :wbversion => 1})
    http.request(request).body
  end

  def self.encoderunmber(str)
    str = str.to_s
    sup_str = ""
    0.upto(str.length-1) do |i|
      s = i%2==0 ? "#{newpass(2)}" : "#{newpass(1)}"
      new_str = "#{str.at(i)}" + "#{s}"
      sup_str += "#{new_str}"
    end
    return sup_str.to_s
  end
  
  def self.decoderunmber(str)
    str = str.to_s
    n_st = ""
    i = str.length%5 == 0 ?  str.length/5 : (str.length/5)+1
    1.upto i do |j|
      h = (j-1)*5
      dup =  str[h..(h+4)] 
        n_st += dup.at(0)
        n_st += dup.at(3) if !dup.at(3).blank?
    end
   return n_st.to_s
  end

  def self.newpass(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

  #获得单个的用户信息
  def self.get_user_info(appkey, appsecret, openid, openkey)
    url = URI("https://open.t.qq.com/api/user/info")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/user/info")}&#{URI.escape("openid=#{openid}&oauth_version=2.a&scope=all")}&#{appsecret}"
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url.path+"?appid=#{appkey}&format=json&openid=#{openid}&openkey=#{openkey}&reqtime=#{Time.now.to_i}&sig=#{current_sig}&wbversion=1")
    return merge_info(JSON.parse(http.request(request).body)["data"])
  end

  #获得单个的用户信息
  def self.get_user_infos(appkey, appsecret, openid, openkey, openids)
    url = URI("https://open.t.qq.com/api/user/infos")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/user/infos")}&#{URI.escape("names=#{openids}")}&#{appsecret}&#{appsecret}"
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url.path+"?appid=#{appkey}&format=json&openid=#{openid}&openkey=#{openkey}&names=#{openids}&reqtime=#{Time.now.to_i}&sig=#{current_sig}&wbversion=1")
    return JSON.parse(http.request(request).body)["data"]
  end

  #判断账户的收听关系
  def self.friendship_show(appkey, appsecret, openid, openkey, openids)
    url = URI("https://open.t.qq.com/api/friends/check")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/friends/check")}&#{URI.escape("fopenids=#{openids}&flag=1")}&#{appsecret}"
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url.path+"?appid=#{appkey}&format=json&openid=#{openid}&openkey=#{openkey}&fopenids=#{openids}&flag=1&reqtime=#{Time.now.to_i}&sig=#{current_sig}&wbversion=1")
    begin 
      return JSON.parse(http.request(request).body)["data"][openids]
    rescue Exception => e
      return []
    end
  end

  #获取用户的双向收听列表
  def self.friends_bilateral(appkey, appsecret, openid, openkey, page)
    url = URI("http://open.t.qq.com/api/friends/mutual_list")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/friends/mutual_list")}&#{URI.escape("fopenid=#{openid}&reqnum=30&startindex=#{page}")}&#{appsecret}"
    http = Net::HTTP.new(url.host, url.port)
    # http.use_ssl = true
    request = Net::HTTP::Get.new(url.path+"?appid=#{appkey}&format=json&openid=#{openid}&openkey=#{openkey}&fopenid=#{openid}&reqnum=30&startindex=#{page}&reqtime=#{Time.now.to_i}&sig=#{current_sig}&wbversion=1")
    begin
      
      return JSON.parse(http.request(request).body)["data"]["info"]
    rescue Exception => e
      return nil
    end
  end

  #判断账户的收听关系
  def self.attention_qq(appkey, token, openid, ip, name)
    url = URI("http://open.t.qq.com/api/friends/check")
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Get.new(url.path+"?oauth_consumer_key=#{appkey}&access_token=#{token}&openid=#{openid}&clientip=#{ip}&oauth_version=2.a&names=#{name}&flag=1")
    return JSON.parse(http.request(request).body)["data"].values[0]
  end

  #收听某用户
  def self.attention_info(appkey, token, openid, ip, name)
    url = URI("http://open.t.qq.com/api/friends/add")
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Get.new(url.path+"?oauth_consumer_key=#{appkey}&access_token=#{token}&openid=#{openid}&clientip=#{ip}&oauth_version=2.a&name=#{URI.escape(name)}")
    #Rails.logger.info(http.request(request).body)
  end

  #发表一条微博信息
  def self.put(appkey, appsecret, openid, openkey, content, ip)
    url = URI("http://open.t.qq.com/api/t/add")
    current_sig = Digest::SHA1.hexdigest "#{URI.escape("/t/add")}&#{URI.escape("content=#{content}&clientip=#{ip}")}&#{appsecret}"
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({:appid => appkey, :format => "json", :clientip => ip, :content => content, :openid => openid, :openkey => openkey, :reqtime => Time.now.to_i, :sig => current_sig, :wbversion => 1})
    http.request(request).body
  end


  def self.call_put(appkey, token, openid, ip, content)
    url = URI("http://open.t.qq.com/api/t/add")
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({:oauth_consumer_key => appkey, :access_token => token, :openid => openid, :clientip => ip, :oauth_version => "2.a", :scope => "all", :content => content})
    http.request(request).body
  end

  #转发一条微博
  def self.truan_put(appkey, token, openid, ip, content, reid)
    url = URI("http://open.t.qq.com/api/t/re_add")
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({:oauth_consumer_key => appkey, :access_token => token, :openid => openid, :clientip => ip, :oauth_version => "2.a", :scope => "all", :content => content, :reid => reid})
    Rails.logger.info(http.request(request).body)
  end
  
  #评论一条微博
  def self.sub_comment(appkey, token, openid, ip, content, reid)
    url = URI("http://open.t.qq.com/api/t/comment")
    http = Net::HTTP.new(url.host, "443")
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request.set_form_data({:oauth_consumer_key => appkey, :access_token => token, :openid => openid, :clientip => ip, :oauth_version => "2.a", :scope => "all", :content => content, :reid => reid})
    Rails.logger.info(http.request(request).body)
  end
end
