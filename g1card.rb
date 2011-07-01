require 'rubygems'
require 'stomp'
require 'nokogiri'
require 'base64'
require 'RMagick'
require 'yaml'

def calc_scale_factor(x, y)
  scale_factor = 1.0
  if x > y
    scale_factor = 200.0 / x
  else
    scale_factor = 200.0 / y
  end
  puts "x: #{x}, y: #{y}"
  return scale_factor
end
  

config = YAML::load(File.open(ARGV[0]))
server_config = config[:dev] 
queue = "/queue/IdCard.Vivo"

puts "Consumer for queue #{queue}"

begin
  hash = {
    :hosts => [ server_config ],
    :initial_reconnect_delay => 0.01,
    :max_reconnect_delay => 30.0,
    :use_exponential_back_off => true,
    :back_off_multiplier => 2,
    :max_reconnect_attempts => 0,
    :randomize => false,
    :backup => false,
    :timeout => -1,
    :connect_headers => {},
    :parse_timeout => 5,
  }
  client = Stomp::Client.new hash
  client.subscribe queue, { :ack => :client } do | message|
    message = Nokogiri::XML(message.body)
    date_updated = message.css('DateUpdated').first.text
    ufid = message.css("Ufid").first.text
    image = message.css("Image").first.text
    puts "Ufid: #{ufid}"
    puts "Date Updated: #{date_updated}"
    File.open("#{ufid}.jpeg", 'w') { |f| f.write(Base64.decode64(image)) }
    img = Magick::Image.read("#{ufid}.jpeg").first
    scale_factor = calc_scale_factor(img.rows, img.columns)
    puts "Scale factor #{scale_factor}"
    if scale_factor < 1.0
      resized_img = img.scale(scale_factor)
    else
      resized_img = img
    end
    resized_img.write "#{ufid}_small.jpeg"
  end
  client.join 
  client.close
rescue Exception => e
  puts e.message
  puts e.backtrace
end
