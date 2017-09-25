require 'zabby'
require 'json'
require 'active_support/core_ext/numeric/time'

########################## PARAMETERS ##############################
SERVER = "http://server/zabbix" # Zabbix server URL
USER = "apiusr"                 # Zabbix user with API query rights
PASSWORD = "password"           # Password
MINPRIORITY = 2                 # Minimum priority level
ANIMATE = 5.minutes             # New triggers animation delay
QUERYDELAY = '30s'              # Zabbix API query delay  

#########################################################
# Zabbix groups to dashboard screens mapping :          #
# "Screen1" => [ "Zabbix group 1", "Zabbix group 2" ],  #
# "Screen2" => [ "Zabbix group 3" ]                     #
#########################################################
SCREENS = {
	"Production" => [ "Hypervisors", "Virtual Machines" ],
        "Development" => [ "Zabbix servers" ]
}


########################## CONSTANTS ###############################
NAMES = {
  1 => "info",
  2 => "warn",
  3 => "avrg",
  4 => "high",
  5 => "disa"
}
NAMES.default = "ok"

############################ MAIN ##################################
lastchange = Time.now
set :screens, SCREENS.keys # Pass the list of screens to HTML page

# Initialize the last count hash
lastcount = {}
SCREENS.each do | k, v |
  lastcount[k] = {}
  for i in MINPRIORITY..5
    lastcount[k][i] = 0
  end
end

# Start the scheduler
SCHEDULER.every QUERYDELAY, allow_overlapping: false do
  
  begin
    serv = Zabby.init do
      set :server => SERVER
      set :user => USER
      set :password => PASSWORD
      login
    end
    SCREENS.each do |screen, groups|
      # Get the group IDs
      grps = serv.run {Zabby::Hostgroup.get("filter" =>{"name" => groups},"preservekeys" => true)}
      groupids = grps != [] ? grps.keys() : []

      # Query Zabbix for current problem triggers
      result = serv.run {
      Zabby::Trigger.get(
        "filter" => {"value" => 1 },
        "min_severity" => MINPRIORITY,
        "groupids" => groupids,
        "output" => "extend", 
        "monitored" => 1, 
        "withLastEventUnacknowledged" => 1, 
        "skipDependent" => 1, 
        "selectHosts" => 1,
        "expandDescription" => 1,
        "sortfield" => "lastchange",
        "sortorder" => "DESC")    
      }

      triggers = { 
        0 => [],
        1 => [],
        2 => [],
        3 => [],
        4 => [],
        5 => []
      }
      lastchange = {
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0
      }
      triggerlist = []
      
      # Parse the results
      jsonObj = JSON.parse(result.to_json)
      jsonObj.each do |j|
        prio = j["priority"].to_i
        last = j["lastchange"].to_i
        tgrid = j["triggerid"]
        tlink = SERVER + "/events.php?triggerid=" + tgrid + "&period=2592000"
        hostid = j["hosts"][0]["hostid"]
        hostnme = serv.run {Zabby::Host.get("hostids" => hostid)}[0]["name"]          
        hostnme = hostnme.gsub(/\..*$/, '') # strip domain name if necessary
        descr = j["description"]
        triggers[prio] << hostnme + " : " + descr
        status = Time.at(last) < (Time.now - ANIMATE) ? NAMES[prio] : NAMES[prio] + "-blink"
        triggerlist << { 
          host: hostnme,
          trigger: descr,
          link: tlink,
          widget_class: "#{status}"
        }
        if last > lastchange[prio] then
          lastchange[prio] = last
        end
      end
      triggerlist = triggerlist.take(12) # Limit the list to 12 entries

      # Loop through priorities to populate the widgets
      for i in MINPRIORITY..5
        total = triggers[i].count
        
        # Set the color of the widget
        if total > 0 then
          status = Time.at(lastchange[i]) < (Time.now - ANIMATE) ? NAMES[i] : NAMES[i] + "-blink"
        else 
          status = "ok" end

        # Limit the displayed events to 3 per widget
        list = triggers[i].uniq
        if list.count > 4 then 
          list = list[0..2]
          list << "[...]"
        end

        # send the data to the widget
        send_event( screen + "_" + NAMES[i], { current: total, last: lastcount[screen][i], status: status, items: list } )
        
        lastcount[screen][i] = total # Copy trigger counts to last value
      end
      send_event( screen + "_list", { items: triggerlist } )
      send_event( screen + "_text", {title: screen, status: "ok"} )
    end
  rescue Zabby::ResponseCodeError => e
    SCREENS.each do |screen, groups|
      send_event( screen + "_text", {title: "DASHBOARD IN ERROR : Cannot connect to Zabbix", status: NAMES[5] + "-blink"} )
    end
  rescue => e
    SCREENS.each do |screen, groups|
      send_event( screen + "_text", {title: "DASHBOARD IN ERROR : #{e}", status: NAMES[5] + "-blink"} )
    end
  end
end

