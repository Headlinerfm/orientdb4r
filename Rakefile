require 'rake/testtask'
require 'rest_client'
require 'orientdb4r'

Rake::TestTask.new do |t|
  t.libs = ['lib', 'test']
  t.pattern = 'test/**/test_*.rb'
end

desc "Run tests"
task :default => :test

namespace :db do

  DB_HOST = 'localhost'
  DB_PORT = 2480
  DB_NAME = 'temp'
  DB_ROOT_USER = 'root'
  DB_ROOT_PASS = ENV['ORIENTDB_ROOT_PASS'] || 'root'

  desc 'Check whether a test DB exists and create if not'
  task :setup4test do
    found = true
    begin
      ::RestClient::Request.new({:url=>"http://#{DB_HOST}:#{DB_PORT}/database/#{DB_NAME}", :method=>:get, :user=>DB_ROOT_USER, :password=>DB_ROOT_PASS}).execute
    rescue Errno::ECONNREFUSED
      fail "server seems to be closed, not running on #{DB_HOST}:#{DB_PORT}?"
    rescue ::RestClient::Unauthorized
      # this is expected reaction if DB does not exist
      puts 'DB does NOT exist -> create'
      found = false
    rescue ::RestClient::Exception => e
      fail "unexpected failure: #{e}"
    end

    if found
      puts 'DB already exists'
    else
      ::RestClient::Request.new({:url=>"http://#{DB_HOST}:#{DB_PORT}/database/#{DB_NAME}/memory", :method=>:post, :user=>DB_ROOT_USER, :password=>DB_ROOT_PASS}).execute
      puts 'DB created'
    end
  end

  namespace :cp do
    desc 'Create cp sample db'
    task :setup do
      ODBClient = Orientdb4r.client(:host=>DB_HOST)
      ODBClient.create_database :database => 'cp', :storage=>:plocal,:type => :graph, :user => 'root', :password => 'root'
      load "support/schema.rb"
    end
    
    desc 'drop db'
    task :drop do
      ODBClient = Orientdb4r.client(:host=>DB_HOST)
      ODBClient.delete_database :database => 'cp', :user => 'root', :password => 'root'
    end

    desc 'Load seed data'
    task :seed do
      ODBClient = Orientdb4r.client(:host=>DB_HOST)
      ODBClient.connect :database => 'cp', :user => 'root', :password => 'root'

      category_list = ['rock', 'pop', 'hip hop', 'punk', 'metal']
      network_list = [1,2,3,4,5]
      user_ids = []
      promo_ids = []

      # create users
      50.times do |i|
        data = {
          user_id: i + 1,
          category_list: category_list.sample(3).push('music')
        }
        ODBClient.command "insert into CpUser CONTENT " + data.to_json
        user_ids.push(i + 1)
      end

      # create promos
      30.times do |i|
        data = {
          promotion_id: i + 1,
          end_date: Time.now + 3600 * 24 * 10,
          category_list: category_list.sample(3).push('music'),
          network_id: network_list.sample(1),
          completed: false
        }
        ODBClient.command "insert into CpPromotion CONTENT " + data.to_json
        promo_ids.push(i + 1)
      end

      # each promo needs a Boost relation to a user
      boosts = {}
      promo_ids.each do |pid|
        uid = user_ids.sample(1).first
        u = ODBClient.query("select * from CpUser where user_id = #{uid}").first
        p = ODBClient.query("select * from CpPromotion where promotion_id = #{pid}").first
        boosts[uid] = pid
        ODBClient.command "create edge Boost from #{u['@rid']} to #{p['@rid']}"
      end

      # some follow relations
      user_ids.sample(15).each do |uid|
        user_ids.sample((rand * 10).floor).reject {|fid| uid == fid}.each do |fid|
          u = ODBClient.query("select * from CpUser where user_id = #{uid}").first
          f = ODBClient.query("select * from CpUser where user_id = #{fid}").first
          ODBClient.command "create edge Follow from #{u['@rid']} to #{f['@rid']}"
        end
      end

      # some view, reject, accept relations
      user_ids.sample(20).each do |uid|
        i = 0
        promo_ids.sample((rand * 5).floor).reject {|pid| boosts[uid] == pid }.each do |pid|
          u = ODBClient.query("select * from CpUser where user_id = #{uid}").first
          p = ODBClient.query("select * from CpPromotion where promotion_id = #{pid}").first
          i += 1
          ODBClient.command "create edge View from #{u['@rid']} to #{p['@rid']}"
          if i % 2 == 0
            edge = 'Accept'
          else
            edge = 'Reject'
          end
          ODBClient.command "create edge #{edge} from #{u['@rid']} to #{p['@rid']}"
        end
      end

    end
  end

end
