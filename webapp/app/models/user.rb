require 'rubygems'
require 'xmlsimple'

class User < ActiveRecord::Base
  devise :database_authenticatable, :confirmable, :lockable, :recoverable,
         :rememberable, :registerable, :trackable, :timeoutable, :validatable,
         :token_authenticatable

  attr_accessible :email, :password, :password_confirmation

  attr_accessible :freeswitch_id, :freeswitch_password

  after_create :freeswitch_hook

  def freeswitch_hook
    id = next_id DeviseExample::Application.config.freeswitch_dir
    pw = gen_password
    write_xml(id, DeviseExample::Application.config.freeswitch_dir, DeviseExample::Application.config.domain, pw)
    self.update_attribute(:freeswitch_id, id)
    self.update_attribute(:freeswitch_password, pw)
    freeswitch_reload DeviseExample::Application.config.freeswitch_dir
  end
end

def gen_password
  pwgen = `which pwgen`.chop!
  if (pwgen.nil?) 
    puts "This program depends on the pwgen utility. Please install it."
    exit 1
  end
  `#{pwgen} -nc`.chop!
end

def write_xml(i, freeswitch_dir, domain, pw)
  openssl = `which openssl`.chop!
  
  if ( openssl.nil? )
    puts "This program depends on the openssl utility. Please install it."
    exit 1
  end

  hash = `echo -n #{i.to_s}:#{domain}:#{pw} | #{openssl} dgst -md5 | cut -d " " -f 2`.chop!
  config = {
    "user"=> {
      i.to_s => {
      "mailbox" => i.to_s,
      "variables" => [{
        "variable" => [{
        "name" => "accountcode",
        "value"=> i.to_s
      },
      {
        "name" => "user_context",
        "value" => "default"
      },
      {
        "name" => "effective_caller_id_name",
        "value" => "Extension #{i.to_s}"
      },
      {
        "name" => "effective_caller_id_number",
        "value" => i.to_s
      }]}],
      "params" => [{
        "param" => [{
          "name" => "a1-hash",
          "value" => hash 
        },
        {
          "name" => "vm-password",
          "value" => hash
        }]}]
      }
    }
  }
  xml_config = XmlSimple.xml_out(config, { 'KeyAttr' => 'id', 'RootName' => "include" })
  fh = File.new(File.join(freeswitch_dir, "conf", "directory", "default", String(i) + ".xml"), "w")
  fh.write(xml_config)
  fh.close
#  concise_string = i.to_s + ":" + pw
#  user_list << concise_string + "\n"
#  puts concise_string
end

def next_id(freeswitch_dir)
  files = Dir.glob(File.join(freeswitch_dir, "conf", "directory", "default", "[0-9]*.xml"))
  remove_list = []
  files.each { |x| remove_list << /.*([0-9]{4}).xml/.match(x)[1] }

  first = 1000
  last = 9999
  valid_list = (first..last).reject {|x| files.include?(x)}

  valid_list[rand(valid_list.length)]
end

def freeswitch_reload(freeswitch_dir)
  res = `#{freeswitch_dir}/bin/fs_cli -x reloadxml`
  puts res
end

#tests:
#puts next_id "/home/zach/freeswitch"
#write_xml(1234, "/home/zach/freeswitch", "boxysean.com")

