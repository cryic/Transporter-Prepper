#
#  errorlog.rb
#  TransporterPackager
#
#  Created by Mat Clutter on 11/3/11.
#  Copyright 2011 darumatou. All rights reserved.
#


class Errorlog
  attr_accessor :errors, :dontbelong

  def initialize #(klass,t)
    @errors = Array.new
    @dontbelong = Array.new
    #@kl = klass #controller object passed; usually 'self'
    #@writer = t #symbol of output method name; example, :write_to_screen
    #@writer = writemethod
  end

  # def <<(er)
  #   @errors << er 
  # end

  def flash(message)
    if @history
      @history << message
    else
      @history = Array.new
      @history << message
    end
    writethis @history.last
  end

  def report
    writethis "\n\n"
    writethis "=" * 5 + "Error Report" + "=" * 5
    if @errors.empty?
      writethis "there are no errors. congratulations!"
    else
      if @errors.length == 1
        writethis "there was #{@errors.length} error:"
      elsif @errors.length > 1
        writethis "there were #{@errors.length} errors:"
      end
      @errors.each do |er|
        writethis er
      end
    end
    writethis "+" * 10
    if @dontbelong.empty?
      writethis "all files are accounted for. congratulations!"
    else
      writethis "some files that might not belong:"
      @dontbelong.each do |er|
        writethis er
      end
    end
  end

  def writethis(message) #convenience method for using the controller's output method
    #@kl.send @writer, message
    puts message
  end
end