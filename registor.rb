#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'yaml'
require 'watir-webdriver'
require 'openssl'
require 'base64'
require 'optparse'

list = YAML.load_file(
  File.join(File.dirname(File.expand_path(__FILE__)), 'list.yml'))
key_file = File.join(File.dirname(File.expand_path(__FILE__)), 'key.ci')
username = ''
password = ''
exceptions = []
temporary = []

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = 'USAGE: registor.rb [options]'

  opts.on('-e NICKNAME1,NICKNAME2, ...',
          '--EXCEPT NICKNAME1,NICKNAME2, ...',
          Array, 'Except the people of following typing') do |value|
    options[:exceptions] = value
  end

  opts.on('-t ID1, ID2, ...',
          '--temporary ID1, ID2, ...',
          Array, 'Add temporary people') do |value|
    options[:temporary] = value
  end

  options[:login] = false
  opts.on('-l', '--login', 'Change the login username and password') do
    options[:login] = true
  end
end

option_parser.parse!

def set_u_p
  puts 'Please tell me your username and password'
  username, password = gets[0..-2], gets[0..-2]

  cipher = OpenSSL::Cipher::AES256.new(:CBC)
  cipher.encrypt

  File.open(key_file, 'w') do |f|
    f.write Base64.encode64(cipher.random_key)
    f.write Base64.encode64(cipher.random_iv)
    f.write Base64.encode64(
              cipher.update("#{username},#{password}") + cipher.final)
  end
end

set_u_p unless File.exist? key_file

username = password = ''

File.open(key_file, 'r') do |f|
  decipher = OpenSSL::Cipher::AES256.new(:CBC)
  decipher.decrypt
  decipher.key = Base64.decode64(f.readline)
  decipher.iv = Base64.decode64(f.readline)

  u_p_b = f.readline
  u_p = decipher.update(Base64.decode64(u_p_b)) + decipher.final
  username = u_p.split(',')[0]
  password = u_p.split(',')[1]
  puts username + "\n" + password
end

flag = :chrome
begin
  b = Watir::Browser.new flag
rescue Selenium::WebDriver::Error::WebDriverError => e
  if e.match(/[C|c]hrome/)
    flag = :firefox
    retry
  elsif e.match(/[F|f]irefox/)
    flag = :ie
    retry
  elsif e.match(/[IEDriverServer|IE]/)
    flag = :safari
    retry
  else
    raise 'None of Webdriver is avaliable'
  end
end

exceptions = options[:exceptions] unless options[:exceptions].nil?

temporary = options[:temporary] unless options[:temporary].nil?

set_u_p unless options[:login] == false

b.goto 'http://124.205.120.190/ischool/main/Login.aspx'
b.text_field(id: 'UcLogin1_tbUser').set username
b.text_field(name: 'UcLogin1$tbPass').set password
b.button(name: 'UcLogin1$ibLogin').click

def sign(i, b, number)
  if i < 8
    b.text_field(id: "myGridView_ctl0#{i + 2}_txtSTUD_CODE").set number
  else
    b.text_field(id: "myGridView_ctl#{i + 2}_txtSTUD_CODE").set number
  end
end

begin
  if b.text.include? '您好'
    puts 'Log in'
    b.goto 'http://124.205.120.190/ischool/main/Main.aspx?Target=NightStudy_UC/ucNightStudyCheckin'
    if b.text.include? '选择自习时段'
      puts 'Got into the page'
      b.text_field(id: 'txtROOM_PWD').set list['class']['number']
      last = 0
      list['class']['people'].each_with_index do |p, i|
        sign(i, b, p['number']) unless exceptions.include? p['nick']
        last = i
      end

      temporary.each_with_index do |p, i|
        sign(i + last + 1, b, p)
      end

      b.button(name: 'btnSave').click
      if b.alert.exists? && /^保存成功/.match(b.alert.text)
        b.alert.ok
        puts 'Save OK'

        exceptions.each do |p|
          fail 'Has Except' if b.text.include? p
        end
      else
        fail "Save Error: #{b.alert.text}"
      end
    else
      fail 'Page Error'
    end
  else
    fail 'Login Error'
  end
ensure
  sleep 5
  b.close
end
