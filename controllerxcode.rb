#
#  controller.rb
#  TransporterPackager
#
#  Created by Mat Clutter on 10/24/11.
#  Copyright 2011 darumatou. All rights reserved.
#

#require 'errorlog'
#require 'package'

class Controller
    
    attr_accessor :destination_path,:mx_filetypes,:textview,:start_btn
    
    def browse(sender)
        # Create the File Open Dialog class.
        dialog = NSOpenPanel.openPanel
        # Disable the selection of files in the dialog.
        dialog.canChooseFiles = false
        # Enable the selection of directories in the dialog.
        dialog.canChooseDirectories = true
        # Disable the selection of multiple items in the dialog.
        dialog.allowsMultipleSelection = false
        
        # Display the dialog and process the selected folder
        if dialog.runModalForDirectory(nil, file:nil) == NSOKButton
            # if we had a allowed for the selection of multiple items
            # we would have want to loop through the selection
            #destination_path = String.new
            pathname = dialog.filenames.first
            destination_path.stringValue = pathname
            
        end
    end
    
    #    def which_radio(sender)
    #        selButton = sender.selectedCell
    #        #write_output "the button was tag: #{selButton.tag}"
    #        case selButton.tag
    #        when 0
    #            mx_filetypes.enabled = true
    #        when 1
    #            mx_filetypes.enabled = false
    #            #ar = mx_filetypes.selectedCells
    #            #ar.each do |b|
    #            #    puts b.class
    #            #end
    #            mx_filetypes.deselectAllCells
    #        end
    #    end
    
    def log(message)
        NSLog message
    end
    
    def write_output(message)
        #log message
        #textview.string = message
        oldlog = textview.string
        newlog = oldlog + message.to_s + "\n"
        textview.string = newlog
    end
        
    def get_asset_types
        ar = mx_filetypes.cells
        wanted = Array.new
        ar.each do |cell|
            if cell.state == 1
                case cell.tag
                    when 0
                    wanted << :full
                    when 1
                    wanted << :preview
                    when 2
                    wanted << :artwork
                end
            end
        end
        return wanted
    end
    
    def lets_go(sender)
        start_btn.enabled = false
        need = get_asset_types
        #need.each do |thing|
        #    write_output thing
        #end
        run(destination_path.stringValue,need)
        #        begin
        #            Main.run(destination_path.stringValue,need)
        #        rescue
        #            write_output "Something has gone very wrong"
        #        ensure
        #            start_btn.enabled = true
        #        end
        start_btn.enabled = true
    end
    
    
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
            write_output "couldn't get eISBN from filename: #{name}"
            write_output "make sure that the file is named correctly."
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
                if ! type.empty?
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
                    throw(:invalid,"#{eisbn}: #{path} is an extra file. Check package options above if you want this asset type included.") if not types.include? type
                end      
                types.each do |t|
                    #puts t
                    throw(:invalid,"#{eisbn}: #{t} is missing. Make sure that you included all desired files and check filenames.") if not typehash.has_key? t
                end
                write_output "#{eisbn} is valid!"
                validatedh[eisbn] = typehash
                nil
            end
            write_output "invalid: #{invalid}"
            if invalid
                #puts "#{eisbn} is missing #{invalid}"
                @err.errors << invalid
            end
        end
        return validatedh
    end
    
    #### original
    # def validateEisbnHash(h,types)
    #   validatedh = Hash.new
    #   h.each do |eisbn,typehash|
    #     puts eisbn
    #     invalid = catch(:invalid) do
    #       types.each do |t|
    #         puts t
    #         throw(:invalid,t) if not typehash.has_key? t
    #       end
    #       puts "#{eisbn} is valid!"
    #       validatedh[eisbn] = typehash
    #       nil
    #     end
    #     puts "invalid: #{invalid}"
    #     if invalid
    #       #puts "#{eisbn} is missing #{invalid}"
    #       @err.errors << "#{eisbn} is missing #{invalid}"
    #     end
    #   end
    #   return validatedh
    # end
    
    def run(path,guireturned)
        #puts "started running"
        #write_output "started running"
        #gui will return array in order of precedence, i.e. [:full,:preview,:artwork]
        
        #guireturned = [:full,:preview,:artwork]
        #guireturned = [:full,:preview]
        #guireturned = [:full,:artwork]
        #guireturned = [:preview,:artwork]
        #guireturned = [:full]
        #guireturned = [:preview]
        #guireturned = [:artwork]
        
        #++++++ main logic
        #folder = ARGV[0]
        folder = path
        @err = Errorlog.new(self,:write_output)
        #puts folder
        #puts @err
        folderitems = Dir.glob(File.join(folder, "*"))
        
        eisbns = build_eisbn_hash(folderitems)
        write_output "prior hash:"
        write_output eisbns
        eisbns = validate_eisbn_hash(eisbns,guireturned)
        write_output "after hash:"
        write_output eisbns
        #responses = Array.new
        eisbns.each do |eisbn,filelist|
            #puts @err
            response = Package.new(eisbn,filelist,folder,@err)
            if response == "package created"
                @err.flash "Package for #{eisbn} was successfully created."
            elsif response == nil
                @err.flash "something went horribly wrong."
            else
                @err.flash "not sure what happened."
            end
        end
        @err.report
    end
    
    
end