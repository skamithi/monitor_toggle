module NvControlDpy
  BIN_FILE = '/usr/local/bin/nv-control-dpy'

  # return an array of connected monitors.
  # monitors may be connected and not active
  def self.get_probed_displays
    NvControlDpy::exec(:keyword => 'probe-dpys').split(/.*GPU-0.*/)[1].split(/\n/)
  end

  # Get the current display mask from nv-control-dpy
  def self.get_display_mask
    NvControlDpy::exec(:keyword => 'get-associated-dpys').each do |line|
      if line =~ /device mask/
        return line.match(/0x\d{8}/)[0].to_i(16)
      end
    end
    return 0
  end

  # returns an hash of preferred modelines in the format
  # key of the hash is the connection type e.g dfp-0
  # value of the hash is the resolution as a string e.g "1680x1050"
  def self.get_max_modelines(monitor_list)
    modelines = {}
    current_monitor = nil
    NvControlDpy::exec(:keyword => 'print-modelines').each do |line|
      line.strip!
      if line =~ /Modelines for (.*):/ && monitor_list.find_by_name($1)
        current_monitor = monitor_list.find_by_name($1).connection_type
      elsif current_monitor  && line =~/source=edid.*"(\d+x\d+)"/
        res = $1.clone
        modelines[current_monitor.gsub('-','_').downcase.to_sym]  = res
        current_monitor = nil
      end
    end
    modelines
  end

  # Add a metamode to the list.
  # return the metamode ID assigned to that metamode.
  def self.activate_metamode(str)
    NvControlDpy::exec({:keyword => 'add-metamode', :arg => str}, true)
    get_metamode_id(str)
  end


  # Get the ID used by xrandr to set to select the correct metamode
  def self.get_metamode_id(metamode)
    xrandr_id = nil
    xrandr_id = NvControlDpy::exec(:keyword => 'print-metamodes').find do |line|
         line_types = Array.new
         connection_types = metamode.split(',').collect { |x| x.split(':')[0].strip if x !~ /NULL/ }.compact
          line_id = line.match(/id=(\d+)/)
          if line_id
            line_types = line.split("::")[1].strip.split(',').map { |x| x.split(':')[0].strip if x =~ /nvidia/ }.compact
            count = (connection_types & line_types.to_a).count
            return line_id[1] if count == connection_types.count
         end
    end
  end

  # Set the display mask
  def self.set_display_mask(mask)
    NvControlDpy::exec({:keyword => 'set-associated-dpys', :arg => mask}, true)
  end

  # format display mask from integer to hex format
  # compatible with nv-control-dpy
  def format_display_mask(num)
    "0x#{num.to_s(16).rjust(8,'0')}"
  end

  private

  # Executes different options of nv-control-dpy
  def self.exec(options = {}, send_to_dev_null = nil)
    #dev_null = (send_to_dev_null)?  '> /dev/null' : ''
    dev_null = ''
        `#{BIN_FILE} --#{options[:keyword]} '#{options[:arg].to_s}' #{dev_null}`
  end

end

