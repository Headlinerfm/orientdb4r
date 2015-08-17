ODBClient.connect :database => 'cp', :user => 'root', :password => 'root'

# create cp_users class
ODBClient.create_class 'CpUser',{:extends=>"V"} do |c|
  c.property 'user_id', :integer, :notnull => true
  c.property 'category_list', :embeddedlist
end
ODBClient.command "create index CpUserIdx on CpUser (user_id) unique"



# create cp_promotions class
ODBClient.create_class 'CpPromotion',{:extends=>"V"} do |c|
  c.property 'promotion_id', :integer, :notnull => true
  c.property 'end_date', :string, :notnull => true
  c.property 'category', :embeddedlist, :notnull => true
  c.property 'network_id', :embeddedlist, :notnull => true
  c.property 'completed', :boolean, :notnull => true
end
ODBClient.command "create index CpPromotionIdx on CpPromotion (promotion_id) unique"



# create edge boost
ODBClient.create_class 'Boost',{:extends=>"E"}
ODBClient.command "create property Boost.out link CpUser"
ODBClient.command "create property Boost.in link CpPromotion"
ODBClient.command "create index BoostIdx on Boost (out,in) unique"

# create edge view
ODBClient.create_class 'View',{:extends=>"E"}
ODBClient.command "create property View.out link CpUser"
ODBClient.command "create property View.in link CpPromotion"
ODBClient.command "create index ViewIdx on View (out,in) unique"

# create edge accept
ODBClient.create_class 'Accept',{:extends=>"E"}
ODBClient.command "create property Accept.out link CpUser"
ODBClient.command "create property Accept.in link CpPromotion"
ODBClient.command "create index AcceptIdx on Accept (out,in) unique"

# create edge reject
ODBClient.create_class 'Reject',{:extends=>"E"}
ODBClient.command "create property Reject.out link CpUser"
ODBClient.command "create property Reject.in link CpPromotion"
ODBClient.command "create index RejectIdx on Reject (out,in) unique"

# create edge follow
ODBClient.create_class 'Follow',{:extends=>"E"}
ODBClient.command "create property Follow.out link CpUser"
ODBClient.command "create property Follow.in link CpUser"
ODBClient.command "create index FollowIdx on Follow (out,in) unique"

# create edge block
ODBClient.create_class 'Block',{:extends=>"E"}
ODBClient.command "create property Block.out link CpUser"
ODBClient.command "create property Block.in link CpUser"
ODBClient.command "create index BlockIdx on Block (out,in) unique"
