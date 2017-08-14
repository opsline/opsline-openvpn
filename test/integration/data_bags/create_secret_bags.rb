require 'rubygems'
require 'chef/encrypted_data_bag_item'

secret = Chef::EncryptedDataBagItem.load_secret('encrypted_data_bag_secret')


puts ARGV[1]
puts ARGV[0]

file = File.open("#{ARGV[1]}")
data = ""
file.each {|line|
  data << line
}

encrypted_data = Chef::EncryptedDataBagItem.encrypt_data_bag_item(JSON.parse(data), secret)

File.open("../data_bags/#{ARGV[0]}/#{ARGV[1]}", 'w') do |f|
  f.print encrypted_data.to_json
end

File.delete(ARGV[1])