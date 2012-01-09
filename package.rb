#
#  package.rb
#  TransporterPackager
#
#  Created by Mat Clutter on 10/31/11.
#  Copyright 2011 darumatou. All rights reserved.
#

require 'rubygems'
require "net/http"
require "fileutils"
require "builder"
require "digest/md5"

class Package
  attr_accessor :response
  
  def initialize(eisbn,filelist,folder,errlog)
    @eisbn = eisbn
    @filelist = filelist
    @log = errlog
    @workfold = folder
    @fetcheddata = fetch_metadata
    #puts "it fetched?"
    if @fetcheddata != nil
      create_package
    else
      return nil
    end
  end
  
  def create_package
    itmspfolder = make_package_dir
    create_metadata(itmspfolder)
    @response = "package created"
  end
  
  def fetch_metadata
    url = ### PUT METADATA URL HERE ### << @eisbn
    res = ""
    stuff = catch(:done) do
      begin
        puts "starting grab"
        res = Net::HTTP.get(URI.parse(url))
      rescue SocketError
        @log.flash "Could not connect to Metadata Fetcher; check connection."
        return nil
      end
      throw(:done,res) if res =~ /\<title\>Error Occurred While Processing Request\<\/title\>/
      return res
    end
    if stuff
      m = res.match(/Error\!.+?\n/)
      #puts m[0]
      @err.flash "Okay, MDF failed."
      @err.flash "MDF's error message: #{m[0]}"
      return nil
    end
  end
  
  def create_metadata(itmspfolder)
    assets = asset_xml_writer(itmspfolder)
    full_xml = full_xml_writer(@fetcheddata,assets,@eisbn)
    puts "xml created"
    metadatatmp = File.join(itmspfolder,"metadata.tmp")
    File.open(metadatatmp , 'w') { |f| f.write(full_xml) }
    
    formattedxml = `xmllint --format --encode UTF-8 "#{metadatatmp}" 2>&1`
    if $? == 256
      puts "#{@eisbn}: an error occured during xmllint. See 'error.txt' in this title's folder."
      File.open(File.join(itmspfolder,"error.txt") , 'w') { |x| x.write(formattedxml) }
      failfold = File.join(@workfold,"failed")
      if ! File.directory?(failfold)
        FileUtils.mkdir(failfold)
      end
      FileUtils.mv(itmspfolder,failfold)
    end
    #puts $?
    File.open(File.join(itmspfolder,"metadata.xml") , 'w') { |x| x.write(formattedxml) }
    FileUtils.rm(metadatatmp)
  end
  
  
  def make_package_dir
    itmspfolder = File.join(@workfold,"#{@eisbn}.itmsp")
    FileUtils.mkdir(itmspfolder)
    
    @filelist.each_value do |filename|
      FileUtils.mv(filename,itmspfolder)
    end
    return itmspfolder
  end
  
  def asset_xml_writer(itmspfolder)
    #$KCODE = 'UTF8'
    puts "trying to build xml"
    build = Builder::XmlMarkup.new(:indent=>2) #may need this line back in ++ :target=>asset_xml,
    puts "after xml init"
    build.assets { |b|
      puts "in build assets"
      @filelist.each do |type, filepath|
        puts "in loop"
        fn = File.basename(filepath)
        nfilepath = File.join(itmspfolder,fn)
        b.asset(:type => type) {
          b.data_file {
            b.file_name(fn);
            b.size(get_filesize(nfilepath))
            b.checksum(get_checksum(nfilepath), :type => "md5")
          }
        }
      end
    }
    puts "building target"
    build.target!
  end
  
  def full_xml_writer( xml_data , asset_xml , eisbn )
    #$KCODE = 'UTF8'
    puts "in full xml writer"
    fullb = Builder::XmlMarkup.new(:indent => 2) #may need this line back in ++ :target => fullxml ,
    fullb.instruct!(:xml, :encoding => "UTF-8")
    fullb.package(:xmlns => "http://apple.com/itunes/importer/publication", :version => "publication4.5") {
      fullb.provider('usrandomhouse');
      fullb.book { |b|
        #b.vendor_id(eisbn);  ++removed due to Bill exporting this value in metadata_fetcher
        b << xml_data;
        b << asset_xml
      }
    }
    fullb.target!
  end
  
  def get_checksum(file)
    #puts file
    Digest::MD5.hexdigest(File.read(file))
  end
  
  def get_filesize(file)
    File.size(file)
  end
  
end