
module NvControlDpy
    BIN_FILE = '/usr/local/bin/nv-control-dpy'

    def self.get_probed_displays
        NvControlDpy::exec(:keyword => 'probe-dpys').split(/.*GPU-0.*/)[1].split(/\n/)
    end

    def self.get_display_mask
        NvControlDpy::exec(:keyword => 'get-associated-dpys').each do |line|
            if line =~ /device mask/
                return line.match(/0x\d{8}/)[0].to_i(16)
            end
         end
         return 0
    end

    # returns an hash of max modelines in the format
    # key of the hash is the connection type e.g dfp-0
    # value of the hash is the resolution as a string e.g "1680x1050"
    def self.get_max_modelines
        modelines = {}
        current_monitor = nil
        NvControlDpy::exec(:keyword => 'print-modelines').each do |line|
            line.strip!
            if line =~ /Modelines for (.*):/ && NvidiaMonitor.find_by_name($1)
                current_monitor = NvidiaMonitor.find_by_name($1).connection_type
            elsif current_monitor  && line =~/source=edid.*"(\d+x\d+)"/
                res = $1.clone
                modelines[current_monitor.gsub('-','_').downcase.to_sym]  = res
                current_monitor = nil
            end
        end
        modelines
    end

    def self.activate_metamode(str)
        NvControlDpy::exec({:keyword => 'add-metamode', :arg => str}, true)
        get_metamode_id(str)
    end


    # Get the ID used by xrandr to set to select the correct metamode
    def self.get_metamode_id(metamode)
        id = nil
        NvControlDpy::exec(:keyword => 'print-metamodes').each do |line|
            line = line.gsub(/@\d+x\d+/,'').gsub(/\s+/,'').gsub('+','')
            count = 0
            metamode.split(',').each do |mm|
                mm = '' if mm =~ /NULL/
                mm = mm.gsub('+','').gsub(/\s+/,'')
                if line =~ /#{mm}/
                    count += 1
                end
            end
            if count == 2
                id = line.match(/id=(\d+)/)[1]
                return id
            end
        end
        nil
    end

    def self.set_display_mask(mask)
        NvControlDpy::exec({:keyword => 'set-associated-dpys', :arg => mask}, true)
    end

    def format_display_mask(num)
        "0x#{num.to_s(16).rjust(8,'0')}"
    end

    private
        def self.exec(options = {}, send_to_dev_null = nil)
            dev_null = (send_to_dev_null)?  '> /dev/null' : ''
            `#{BIN_FILE} --#{options[:keyword]} '#{options[:arg].to_s}' #{dev_null}`
        end
end

class NvidiaMonitor

    include NvControlDpy

    class << self
        attr_accessor :xrandr_res, :osd_str, :display_mask, :metamodes,
                                :xrandr_id, :mode, :active_monitors
    end

    # Initialize class variable
    @@monitors = []
    @metamodes = {}
    @display_mask = 0
    @active_monitors = []


    # Define instance variables
    attr_accessor :name, :connection_type, :mask, :xres, :yres, :max_resolution

    def initialize(options = {})
         @name = options[:name]
         @connection_type = options[:connection_type]
         @mask = options[:mask]
         @xres = options[:xres]
         @yres = options[:yres]
    end

    def store
        @@monitors << self
    end

    def delete
        @@monitors.delete(self)
    end

    def laptop_lcd?
        self.connection_type == 'DFP-0'
    end

    def connected?
        NvidiaMonitor.active_monitors.each do |nm_type|
            return true if nm_type.downcase == self.connection_type.downcase
        end
        false
    end

    # Takes a string of [x resolution]x[y resolution]
    # eg. "1680x1050" and updates xres and yres
    def add_max_modeline(modeline)
        if modeline =~ /^\d{3,4}x\d{3,4}$/
            self.xres, self.yres = modeline.split(/x/)
        end
    end

    def max_resolution
        [self.xres, self.yres].join('x')
    end

    # Activate this monitor
    # Arguments: <em>metamode_type</em>: could be :absolute,  :external, :right
    def activate(metamode_type)
        display_mask = NvidiaMonitor.display_mask
        unless (self.mask & display_mask) == (self.mask | display_mask)
            new_display_mask = self.mask | display_mask
            NvidiaMonitor.display_mask = new_display_mask
            NvControlDpy::set_display_mask(format_display_mask(new_display_mask))
            self.set_metamode(metamode_type)
        end
   end

    # set nvidia metamode
    # params: orientation -> :right or :absolute, :clone
    def set_metamode(orientation)
        self.set_resolutions
        pos = "+0+0"
        case orientation
            when :right
                first_monitor = NvidiaMonitor.metamodes[0]
                nm = NvidiaMonitor.find(first_monitor[:type])
                pos = "+#{nm.xres}+0" if nm
                pos_in_array = 1
            when :clone
                pos_in_array = 1
            else
                pos_in_array = 0
        end
        NvidiaMonitor.metamodes[pos_in_array] = { :type => self.connection_type, :pos => pos }
    end

    # Class Functions

    # Get the list of monitors from probing the GPU
    def self.probe_for_monitors
        @@monitors = []
        NvControlDpy::get_probed_displays.each do |line|
            line.strip!
            if line =~ /\(0x\d{8}\)/
                nm = NvidiaMonitor.new
                left_split = line.strip.split(/:/)
                nm.name = left_split[1].strip
                nm.connection_type = left_split[0].split(/\s+/)[0]
                nm.mask = left_split[0].split(/\s+/)[1].match(/0x\d{8}/)[0].to_i(16)
                nm.store
            end
        end
    end

    # Remove all Members from the monitor list
    def self.reset
        @@monitors = []
        NvidiaMonitor.metamodes = []
        NvidiaMonitor.display_mask = 0
        NvidiaMonitor.active_monitors = []
    end

    # activate metamode
    def self.create_metamode_str
        a = []
        metamode = NvidiaMonitor.metamodes[0]
        a[0] = (metamode) ? "#{metamode[:type]}: nvidia-auto-select #{metamode[:pos]}" : 'NULL'
        metamode = NvidiaMonitor.metamodes[1]
        a[1] = (metamode) ? "#{metamode[:type]}: nvidia-auto-select #{metamode[:pos]}": 'NULL'
        a.join(', ')
    end

    # Finds all nvidia monitors matching a keyword
    # * keyword could be :all or the "type".
    # Example:  NvidiaMonitor.find("DFP-0") or NvidiaMonitor.find(:all)
    def self.find(keyword)
        if keyword == :all
            @@monitors
        else
            NvidiaMonitor.find_by_type(keyword)
        end
    end

    # find nvidia monitor by type. Example: NvidiaMonitor.find_by_type("DFP-0")
    def self.find_by_type(type)
        @@monitors.each do |nm|
            return nm if nm.connection_type.downcase.gsub(/\s+/,'') == type.downcase.gsub(/\s+/,'')
        end
    end

    # find nvidia monitor by name.  Example: NvidiaMonitor.find_by_name("NEC")
    def self.find_by_name(name)
        @@monitors.each do |nm|
            return nm if nm.name.downcase.gsub(/\s+/,'') == name.downcase.gsub(/\s+/,'')
        end
        nil
    end

    def set_resolutions
        res = NvControlDpy::get_max_modelines
        self.add_max_modeline(res[self.connection_type.gsub('-','_').downcase.to_sym])
    end

    # Change monitor mode dynamically
    def self.change_monitor_mode
        # Reset monitor list
        NvidiaMonitor.reset
        NvidiaMonitor.active_monitors = get_active_monitors
        probe_and_get_display_mask

        # Dont bother moving on if probed monitor size is 1
        if (NvidiaMonitor.find(:all).size ==1)
            NvidiaMonitor.mode = :lcd
            NvidiaMonitor.osd_str = "LCD Mode: 1 Monitor"
            return
        end

        NvidiaMonitor.mode = determine_monitor_state
        res  = NvidiaMonitor::activate

        # Check if the Metamode exists. If not add it to the list
        # Get ID of metamode and total resolution
        id  = NvControlDpy.activate_metamode(NvidiaMonitor.create_metamode_str)
        NvidiaMonitor.xrandr_res = res
        NvidiaMonitor.xrandr_id = id
        NvidiaMonitor.osd_str =
                "#{NvidiaMonitor.mode.to_s.capitalize_except_lcd} " +
                "Mode: #{NvidiaMonitor.find(:all).size} Monitors"
        ## run xrandr
        run_xrandr(NvidiaMonitor.xrandr_res.join('x'), id)
    end

    def self.run_xrandr(res, id)
        `xrandr -s #{res} -r #{id}`
    end


    private

    def self.get_active_monitors
        active_monitors = []
        NvControlDpy::exec(:keyword => 'print-current-metamode').each do |line|
            if line =~ /current metamode/
                monitors = line.split(/::\s+/)[1].split(',')
                monitors.each do |m|
                    active_monitors << m.match(/(\w+-\w+):/)[1] unless m =~ /NULL/
                end
            end
        end
        active_monitors
    end

    def self.activate
        # Create Metamode String and activate the monitor
        external_monitor = 0
        mode = NvidiaMonitor.mode
        res = [0, 0]
        NvidiaMonitor.display_mask = 0
        NvidiaMonitor.find(:all).each do |nm|
            if mode == :lcd
                if nm.laptop_lcd?
                    nm.activate(:absolute)
                    res = [nm.xres, nm.yres]
                end
            elsif mode == :clone
                if nm.laptop_lcd?
                    nm.activate(:absolute)
                else
                    nm.activate(:clone)
                end
                res = [ [res[0].to_i, nm.xres.to_i].max, [res[1].to_i,nm.yres.to_i].max]
            elsif mode == :external
                unless nm.laptop_lcd?
                    external_monitor += 1
                    if external_monitor == 1
                        nm.activate(:absolute)
                    else
                        nm.activate(:right)
                    end
                    res = [res[0].to_i + nm.xres.to_i, [res[1].to_i, nm.yres.to_i].max]
                end
            end
        end
        res
    end

    def self.probe_and_get_display_mask
        NvidiaMonitor.probe_for_monitors
        NvidiaMonitor.display_mask = NvControlDpy.get_display_mask
    end

    def self.determine_monitor_state
        dfp_0 = NvidiaMonitor.find('DFP-0')
        num_of_monitors = NvidiaMonitor.find(:all).size
        case num_of_monitors
            when 3
                return :external if dfp_0.connected?
            when 2
                second_monitor = nil
                NvidiaMonitor.find(:all).each do |nm|
                    second_monitor = nm unless nm.laptop_lcd?
                end
                if dfp_0.connected? && !second_monitor.connected?
                    return :external
                elsif !dfp_0.connected? && second_monitor.connected?
                    return :clone
                end
        end
        return :lcd
    end

end

# Addition to the String class
# Make 'lcd' uppercase and capitalize everything else
class String
  # If you call capitalize on lcd, make it uppercase LCD
  def capitalize_except_lcd
      return "LCD" if self.downcase == 'lcd'
      self.capitalize
  end

end
