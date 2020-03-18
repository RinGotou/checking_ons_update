require 'nokogiri'
require 'open-uri'
require 'toml-rb'
require 'net/http'

$main_site_url = 'http://onscripter.osdn.jp/'
$request_str = 'onscripter.osdn.jp'
$site_url = $main_site_url + 'onscripter.html'
$update_record_file = './ons_update.toml'
$ons_downloads_dir = './ons_downloads'

def create_local_info(current_version_tag)
    toml_hash = {
        'current' => current_version_tag
    }

    cache = TomlRB.dump(toml_hash)
    toml_file = File.open($update_record_file, 'w+')
    if toml_file
        toml_file.syswrite(cache)
    end
end

def checking_download_dir
    if !Dir.exist? $ons_downloads_dir
        Dir.mkdir $ons_downloads_dir
    end
end

def download_code_pack(version_string, local_file_path)
    checking_download_dir()

    archive = File.open(local_file_path, 'wb+')
    begin
        puts 'Start downloading...'
        Net::HTTP.start($request_str) do |http|
            response = http.get('/' + version_string)
            archive.write(response.body)
        end
    rescue => exception
        puts 'Downloading is failed.'
        puts exception.message
        return
    ensure
        archive.close
    end

    puts 'Downloading is complete.'
end

def processing_update_info(table)
    hyper_texts = table.xpath('//td/a')
    current_version_string = hyper_texts[0]['href']
    current_version_tag = current_version_string[11..18]
    local_path = $ons_downloads_dir + '/' + current_version_string

    toml_file = nil
    begin
        toml_file = TomlRB.parse(File.open($update_record_file))
        file_exist = File.exist?(local_path)
        if current_version_tag != toml_file['current']
            puts 'There\'s a newer version.'
            download_code_pack(current_version_string, local_path)
        else 
            if file_exist && (File.size?(local_path) != nil)
                puts 'Already downloaded.'
            else
                puts 'Redownloading...'
                download_code_pack(current_version_string, local_path)
            end
        end
    rescue ParseError => exception
        puts 'Record is invalid. Create record with current version info.'
        create_local_info(current_version_tag)
        download_code_pack(current_version_string, local_path)
    rescue Errno::ENOENT =>exception
        puts 'Record is invalid. Create record with current version info.'
        create_local_info(current_version_tag)
        download_code_pack(current_version_string, local_path)
    end    
end

puts 'Connect to ONScripter site...'
site_html = nil
begin
    site_html = Nokogiri::HTML.parse(open($site_url))
rescue => exception
    puts exception.message
    puts 'Press enter to exit.'
    gets
    exit
end

begin
    puts 'Successful. Reading info...'
    cache = site_html.xpath('//table')
    processing_update_info(cache[0])
rescue => exception
    puts exception.message
    puts exception.backtrace.inspect
    puts exception.class.to_s
end

