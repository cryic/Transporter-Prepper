require "errorlog.rb"
require "package.rb"
require "builder"

def get_eisbn(name) #string; removes hyphens then checks for 13-digits
  #add check to only grab 13 digit from filename; check File.filename?
  #name = File.basename(path)
  nohyphens = name.gsub("-","") #just in case; mainly for artwork
  missing = catch(:finish) do
    m = nohyphens.match(/\d{13}/)
    throw(:finish,"failed") if m == nil
    eisbn = m[0]
    return eisbn
  end
  if missing
    #puts "missing: #{missing}"
    puts "couldn't get eISBN from filename: #{name}"
    puts "make sure that the file is named correctly."
    return missing
  end
end

def build_eisbn_hash(filelist) ## takes an array of filenames
  #h = Array.new
  h = Hash.new
  filelist.each do |f|
    name = File.basename(f)
    eisbn = get_eisbn(name)
    #h << eisbn if eisbn != "failed"
    if eisbn != "failed"
      type = ""
      case name
      when /\.png|\.jpeg|\.jpg|\.tif{1,2}$/i
        type = :artwork
      when /\.epub$/i
        if name =~ /_prev_/i
          type = :preview
        else
          type = :full
        end
      end
      #if ! type.empty?
      if type.class == Symbol
        if h.has_key? eisbn
          h[eisbn][type] = h.fetch(h[eisbn][type],f)
        else
          h[eisbn] = {type => f}
        end
      else
        @err.dontbelong << f
      end
    end
  end
  return h
end

def validate_eisbn_hash(h,types)
  validatedh = Hash.new
  h.each do |eisbn,typehash|
      #puts eisbn
    invalid = catch(:invalid) do
      typehash.each do |type,path|
        throw(:invalid,"#{eisbn}: #{File.basename(path)} was not set to be packaged. Check package options above if you want this asset type included.") if not types.include? type
      end      
      types.each do |t|
        #puts t
        throw(:invalid,"#{eisbn}: #{t} is missing. Check that all wanted files are present and named properly.") if not typehash.has_key? t
      end
      puts "#{eisbn} is valid!"
      validatedh[eisbn] = typehash
      nil
    end
    puts "invalid: #{invalid}"
    if invalid
      #puts "#{eisbn} is missing #{invalid}"
      @err.errors << invalid
    end
  end
  return validatedh
end

#++++++ main logic
folder = ARGV[0]
guioption = ARGV[1]
puts guioption
#puts guioption.class
#gui will return array in order of precedence, i.e. [:full,:preview,:artwork]
guireturned = []
case guioption
when "0"
  guireturned << :full
  guireturned << :preview
  guireturned << :artwork
when "1"
  guireturned << :full
  guireturned << :preview
when "2"
  guireturned << :full
  guireturned << :artwork
when "3"
  guireturned << :preview
  guireturned << :artwork
when "4"
  guireturned << :full
when "5"
  guireturned << :preview
when "6"
  guireturned << :artwork
end
#guireturned = [:full,:preview,:artwork]
#guireturned = [:full,:preview]
#guireturned = [:full,:artwork]
#guireturned = [:preview,:artwork]
#guireturned = [:full]
#guireturned = [:preview]
#guireturned = [:artwork]

puts guireturned
#folder = path
@err = Errorlog.new #(self,:puts)
#puts folder
#puts @err
folderitems = Dir.glob(File.join(folder, "*"))
if folderitems.length == 0
  abort "That folder does not exist or there are no files in it."
end

eisbns = build_eisbn_hash(folderitems)
puts "prior hash:"
eisbns.each do |eisbn,files|
  puts "#{eisbn} => "
  files.each do |type,files|
    puts "#{type} => #{files}"
  end
end
eisbns = validate_eisbn_hash(eisbns,guireturned)
puts "after hash:"
eisbns.each do |eisbn,files|
  puts "#{eisbn} => "
  files.each do |type,files|
    puts "#{type} => #{files}"
  end
end
#responses = Array.new
eisbns.each do |eisbn,filelist|
   #puts @err
   p = Package.new(eisbn,filelist,folder,@err)
   puts p.response
   if p.response == "package created"
       @err.flash "Package for #{eisbn} was successfully created."
   elsif p.response == nil
       @err.flash "something went horribly wrong."
   else
       @err.flash "not sure what happened."
   end
end
@err.report