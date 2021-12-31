require 'sinatra'
require 'securerandom'
require 'yaml'
require 'ruby-pota-csv-to-adif'

set    :environment, :production
enable :sessions,    :logging


#### Methods - Doing this project too quick to do full MVC and proper classes. So it's all here. It works.
def handleSessionUUID()
  unless session[:session_uuid]
    session_uuid = SecureRandom.uuid
    session[:session_uuid] = session_uuid
  else
  	session_uuid = session[:session_uuid]
  end

  return session_uuid
end

def writeToYML(session_uuid, entry)
  tmp_file = "tmp/#{session_uuid}.yml.tmp"
  File.open(tmp_file, "w") { |f| f.write(entry.to_yaml) }

  pre_text  = File.read(tmp_file)
  post_text = pre_text.gsub("---", "")

  File.open("tmp/#{session_uuid}.yml", "a") { |f| f.puts(post_text) }
  File.delete(tmp_file)
end

def refreshLogTable(session_uuid, parameters)
  log_table = []
  
  if File.exist?("tmp/#{session_uuid}.yml")
    YAML.load_file("tmp/#{session_uuid}.yml").reverse_each.to_h.each do |key, value|
      log_table << "<tr><td>#{value['qso_time']}</td><td>#{value['qso_call']}</td><td>#{value['qso_location']}</td><td>#{value['qso_rst']}</td><td>#{value['qso_mode']}</td><td>#{value['qso_frequency']}</td><td><button><a href=\"/delete?delete_id=#{value['qso_call']}_#{value['act_park']}_#{value['act_date']}&mycall=#{params['mycall']}&mypark=#{params['mypark']}&mydate=#{params['mydate']}&mymode=#{params['mymode']}&myfreq=#{params['myfreq']}\">delete</a></button></td></tr>"
    end
  end

  return log_table
end

def deleteLogEntry(session_uuid, qso_id)
  puts "deleting #{qso_id}"
  log = YAML.load_file("tmp/#{session_uuid}.yml")
  log.delete("#{qso_id}")
  
  File.open("tmp/#{session_uuid}.yml", "w") { |f| f.write(log.to_yaml) }
end

def clearLog(session_uuid)
  File.delete("tmp/#{session_uuid}.yml") if File.exist?("tmp/#{session_uuid}.yml")
end

def generateAdif(session_uuid)
  records = []
  records << "CALL,QSO_DATE,TIME_ON,BAND,MODE,OPERATOR,MY_SIG_INFO,SIG_INFO,STATION_CALLSIGN"

  if File.exist?("tmp/#{session_uuid}.yml")
  	my_info = {}
    YAML.load_file("tmp/#{session_uuid}.yml").reverse_each.to_h.each do |key, value|
      if my_info.empty?
        my_info['my_call'] = value['act_call']
        my_info['my_park'] = value['act_park']
        my_info['my_date'] = value['act_date'].gsub('-','')
      end

      band = determineBand(value['qso_frequency'])
      records << "#{value['qso_call']},#{value['act_date']},#{value['qso_time']},#{band},#{value['act_call']},POTA,#{value['act_park']},#{value['act_call']}"
    end
  end

  File.open("tmp/#{my_info['my_call']}@#{my_info['my_park']}-#{my_info['my_date']}.csv", "w") { |f| f.write(records.join("\n")) }

  `ruby-pota-csv-to-adif tmp/#{my_info['my_call']}@#{my_info['my_park']}-#{my_info['my_date']}.csv`

  return "#{my_info['my_call']}@#{my_info['my_park']}-#{my_info['my_date']}.adi"
end

def determineBand(frequency)
  frequency_int = frequency.to_i

  case frequency_int
  when 1800..2000
  	band = "160M"
  when 3500..4000
  	band = "80M"
  when 5330..5403
    band = "60M"
  when 7000..7300
  	band = "40M"
  when 10100..10150
  	band = "30M"
  when 14000..14350
  	band = "20M"
  when 18068..18168
  	band = "17M"
  when 21000..21450
  	band = "15M"
  when 24890..24990
  	band = "12M"
  when 28000..29700
  	band = "10M"
  when 50000..54000
  	band = "6M"
  when 144000..148000
  	band = "2M"
  when 222000..225000
  	band = "1.25M"
  when 420000..450000
  	band = "70CM"
  when 902000..928000
  	band = "33CM"
  when 1240000..1300000
  	band = "23CM"
  else
  	band = "Out of Range"
  end

  return band
end


#### Routes
get '/' do
  session_uuid = handleSessionUUID()
  puts "Session ID: #{session_uuid}"

  current_log_table = refreshLogTable(session_uuid, params).join(" ")

  erb :home, :locals => { :current_log_table => current_log_table, :session_uuid => session_uuid }
end


post '/submit' do
  session_uuid = handleSessionUUID()

  entry = {}
  entry["#{params['qso_call']}_#{params['act_park']}_#{params['act_date']}"] = params

  writeToYML(session_uuid, entry)

  redirect "?mycall=#{params['act_call']}&mypark=#{params['act_park']}&mydate=#{params['act_date']}&mymode=#{params['qso_mode']}&myfreq=#{params['qso_frequency']}"
end


get '/delete' do
  session_uuid = handleSessionUUID()

  deleteLogEntry(session_uuid, params['delete_id'])
  
  redirect "?mycall=#{params['mycall']}&mypark=#{params['mypark']}&mydate=#{params['mydate']}&mymode=#{params['mymode']}&myfreq=#{params['myfreq']}" 
end


get '/clearlog' do
  session_uuid = handleSessionUUID()

  clearLog(session_uuid)

  redirect '/'
end

get '/generateadif' do
  session_uuid = handleSessionUUID()

  file_name = generateAdif(session_uuid)
  file_path = File.expand_path("tmp/#{file_name}")

  puts file_path

  send_file(file_path, :filename => file_name)

  redirect '/'
end


#### In-line ERB Template - yes, I know this is lazy... quick and dirty project to automate something I need...not pretty code to admire. :)
__END__

@@ home
<html>
<head>
  <!-- Font Awesome -->
  <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.8.2/css/all.css">
  <!-- Google Fonts -->
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700&display=swap">
  <!-- Bootstrap core CSS -->
  <link href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.5.0/css/bootstrap.min.css" rel="stylesheet">
  <!-- Material Design Bootstrap -->
  <link href="https://cdnjs.cloudflare.com/ajax/libs/mdbootstrap/4.19.1/css/mdb.min.css" rel="stylesheet">
</head>
<body>

<nav class="navbar navbar-light bg-light">
  <div class="container-fluid">
    <span class="navbar-brand mb-0 h1 col-2">Log4POTA</span>
    <div class="d-flex align-items-center">
      <a href="/generateadif"><button type="button" class="btn btn-primary me-3">Generate ADIF</button></a>
      <a href="/clearlog"><button type="button" class="btn btn-primary me-3">Clear Log</button></a>
  </div>
</nav>	

<div class="container-lg" style="margin-top:25px;">

<form action="/submit" method="POST" class="row row-cols-lg-auto g-3 align-items-center">
  <div class="col-3">
    <div class="input-group">
      <div class="col-4 input-group input-group-text">My Call</div>
      <input required type="text" class="form-control" name="act_call" id="act_call" placeholder="AB1CDE" value="<%= params['mycall'] %>" />
    </div>
  </div>
  <div class="col-3">
    <div class="input-group">
      <div class="input-group-text">Park #</div>
      <input required type="text" class="form-control" name="act_park" id="act_park" placeholder="K-1038" value="<%= params['mypark'] %>"/>
    </div>
  </div>
  <div class="col-3">
    <div class="input-group">
      <div class="input-group-text">Date</div>
      <input required type="date" class="form-control" name="act_date" id="act_date" placeholder="MM/DD/YYYY" value="<%= params['mydate'] %>"/>
    </div>
  </div>
  <div class="col-2">
    <div class="input-group">
      <div class="input-group-text">Mode</div>
      <select class="form-control" name="qso_mode" id="qso_mode"/>
        <option selected value="none"></option>
        <option <%= "selected" if params['mymode'] == "CW"    %> value="CW">CW</option>
        <option <%= "selected" if params['mymode'] == "SSB"   %> value="SSB">SSB</option>
        <option <%= "selected" if params['mymode'] == "FT8"   %> value="FT8">FT8</option>
        <option <%= "selected" if params['mymode'] == "PSK31" %> value="PSK31">PSK31</option>
        <option <%= "selected" if params['mymode'] == "RTTY"  %> value="RTTY">RTTY</option>
      </select>
    </div>
  </div>
  <br>
  <div class="col-2">
    <div class="input-group">
      <div class="input-group-text">Call</div>
      <input required autofocus type="text" class="form-control" name="qso_call" id="qso_call" placeholder="AB1CDE"/>
    </div>
  </div>
  <div class="col-2">
    <div class="input-group">
      <div class="input-group-text">Loc</div>
      <input required type="text" class="form-control" name="qso_location" id="qso_location" placeholder="AL"/>
    </div>
  </div>
  <div class="col-2">
    <div class="input-group">
      <div class="input-group-text">RST</div>
      <input required type="text" class="form-control" name="qso_rst" id="qso_rst" placeholder="599"/>
    </div>
  </div>
  <div class="col-2">
    <div class="input-group">
      <div class="input-group-text">Time</div>
      <input required type="number" class="form-control" name="qso_time" id="qso_time" placeholder="1400"/>
    </div>
  </div>
  <div class="col-3">
    <div class="input-group">
      <div class="input-group-text">kHz</div>
      <input required type="number" step="0.01" class="form-control" name="qso_frequency" id="qso_frequency" placeholder="14065.00" value="<%= params['myfreq'] %>"/>
    </div>
  </div>
  <div class="col-1">
    <button type="submit" class="btn btn-primary">Log</button>
  </div>
</form>

  <table class="table table-hover">
    <tr>
      <th>Time</th>
      <th>Call Sign</th>
      <th>Location</th>
      <th>RST</th>
      <th>Mode</th>
      <th>Frequency</th>
      <th>Delete?</th>
    </tr>
    <%= current_log_table %>
  </table>
</div>
<footer class="bg-light text-center text-lg-start fixed-bottom">
  <!-- Copyright -->
  <div class="text-center p-3" style="background-color: rgba(0, 0, 0, 0.2);">
    © 2020 Copyright:
    <a class="text-dark" href="https://aaronbowman.me/">Aaron Bowman</a> | <small>Session Unique ID: <%= session_uuid %></small>
  </div>
  <!-- Copyright -->
</footer>
</body>
</html>