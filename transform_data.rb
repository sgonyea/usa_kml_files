# This is a junky script that I wrote to transform the
#   Census Bureau's TIGER Shapefiles into separate
#   KML files for each city.

require 'nokogiri'
require 'ostruct'
require 'csv'
require 'fileutils'

downloads = <<-CSV
state,url_id
Alabama,"01"
Alaska,"02"
Arizona,"04"
Arkansas,"05"
California,"06"
Colorado,"08"
Connecticut,"09"
Delaware,"10"
District of Columbia,"11"
Florida,"12"
Georgia,"13"
Hawaii,"15"
Idaho,"16"
Illinois,"17"
Indiana,"18"
Iowa,"19"
Kansas,"20"
Kentucky,"21"
Louisiana,"22"
Maine,"23"
Maryland,"24"
Massachusetts,"25"
Michigan,"26"
Minnesota,"27"
Mississippi,"28"
Missouri,"29"
Montana,"30"
Nebraska,"31"
Nevada,"32"
New Hampshire,"33"
New Jersey,"34"
New Mexico,"35"
New York,"36"
North Carolina,"37"
North Dakota,"38"
Ohio,"39"
Oklahoma,"40"
Oregon,"41"
Pennsylvania,"42"
Rhode Island,"44"
South Carolina,"45"
South Dakota,"46"
Tennessee,"47"
Texas,"48"
Utah,"49"
Vermont,"50"
Virginia,"51"
Washington,"53"
West Virginia,"54"
Wisconsin,"55"
Wyoming,"56"
CSV

states.each do |state|
  state_dir = state.downcase.gsub(/\s+/, '_')
  FileUtils.rm_rf File.join(state_dir, 'cities')
end

def download_url(id)
  "http://www2.census.gov/geo/tiger/TIGER2012/PLACE/tl_2012_#{id}_place.zip"
end

states = []
CSV.parse(downloads, headers: true) do |row|
  state = OpenStruct.new

  state.name      = row['state']
  state.downcase  = state.name.downcase.gsub(/\s+/, '_')
  state.url       = download_url(row['url_id'])
  state.zip_file  = File.basename(state.url)
  state.base_name = state.zip_file.gsub('.zip', '')
  state.shp_file  = File.join(state.downcase, state.base_name + '.shp')
  state.kml_file  = File.join(state.downcase, state.downcase + '.kml')

  state.places_dir = File.join(state.downcase, 'cities--places')

  states << state
end ; nil

states.each do |state|
  FileUtils.mkdir_p state.places_dir

  dest = File.join(state.downcase, state.zip_file)

  unless File.exist?(dest)
    `wget -q "#{state.url}"`
    FileUtils.mv state.zip_file, dest
  end

  `unzip #{dest} -o -d #{state.downcase}/`

  kml_out = File.join(state_dir, "#{state_dir}.kml")
  `ogr2ogr -f KML #{state.kml_file} #{state.shp} #{state.base_name}`

  # Cleanup TIGER stuff:
  Dir[File.join(state.downcase, "#{state.base_name}.*")].each { |fi| FileUtils.rm fi }
end

states.each do |state|
  file  = File.read(state.kml_file)
  xml   = Nokogiri::XML(file)

  file  = file.lines.to_a

  header  = file.first(3).join
  footer  = file.last
  file    = nil

  schema      = xml.search("Schema").to_s
  placemarks  = xml.search("Placemark")

  placemarks.each do |place|
    name        = place.css("name").text
    short_name  = name.downcase.gsub(/[\W\s]+/, '_')
    outfile     = File.join(state.places_dir, "#{short_name}.kml")

    output = header + schema
    output << "#{place}\n"
    output << footer
    output.gsub!(state.base_name, short_name)

    File.open(outfile, "wb") { |fi| fi.puts output }
  end
end
