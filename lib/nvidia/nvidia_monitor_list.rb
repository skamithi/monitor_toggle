require File.dirname(__FILE__) + '/nv_control_dpy'
require File.dirname(__FILE__) + '/nvidia_monitor'
require File.dirname(__FILE__) + '/../xorg_monitor_list'

class NvidiaMonitorList < XorgMonitorList

  include NvControlDpy

  attr_accessor :mask, :metamodes

  # run this to change the monitor mode from :lcd, :clone, :external
  # depending on the number of monitors
  #--
  # TODO add option to select order in which to select the primary monitor
  #++
  def change_monitor_mode
    get_probed_monitor_list

    # Don't bother moving on if the probed monitor size == 1
    # Need to account for condition where monitor is unplugged
    # before switching modes. (if possible)
    if (self.probed_monitors.size == 1)
      self.mode = :lcd
      self.osd_str = "LCD Mode: 1 Monitor"
      return
    end

    get_active_monitor_list
    get_next_monitor_mode
    enable_monitors
    set_monitor_resolution
    activate_monitors
    set_metamodes

    self.xrandr_id = NvControlDpy::activate_metamode(create_metamode_str)
    self.osd_str = "#{self.mode.to_s.capitalize} Mode: #{self.probed_monitors.size} Monitors"
    run_xrandr
  end

  def find_by_name(name)
      self.probed_monitors.find { |i| i.name == name }
  end

  def find_by_connection_type(type)
    self.probed_monitors.find { |i| type  == i.connection_type }
  end

  private

  def enable_monitors
    self.mask = 0
    self.probed_monitors.each do |nm|
        self.mask = self.mask | nm.mask
    end
    NvControlDpy::set_display_mask(format_display_mask(self.mask))
  end

  def activate_monitors
    external_monitor = 0
    res = [0,0]
    self.active_monitors = []
    self.probed_monitors.each do |nm|
      case self.mode
      when :lcd
        if nm.laptop_lcd?
          self.mask = self.mask | nm.mask
          res = [nm.xres.to_i, nm.yres.to_i]
          self.active_monitors << nm
        end
      when :clone
          self.mask = self.mask | nm.mask
          self.active_monitors << nm
          res = [ [res[0].to_i, nm.xres.to_i].max, [res[1].to_i,nm.yres.to_i].max]
      when :external
        unless nm.laptop_lcd?
          external_monitor += 1
          self.mask = self.mask | nm.mask
          self.active_monitors << nm
          res = [res[0].to_i + nm.xres.to_i, [res[1].to_i, nm.yres.to_i].max]
        end
      end
    end

    self.xrandr_res = res
  end

  def set_monitor_resolution
    res = NvControlDpy::get_max_modelines
    self.probed_monitors.each do |nm|
      name = nm.connect_type.gsub('-','_').downcase.to_sym
      nm.change_preferred_modeline(res[name])
    end
  end

  def get_next_monitor_mode
    dfp_0 = self.find_by_connection_type('DFP-0')
    num_of_monitors = self.probed_monitors.size
    self.mode = :lcd
    case num_of_monitors
      when 3
        self.mode = :external if dfp_0.connected?(self.active_monitors)
      when 2
        second_monitor = nil
        self.probed_monitors.each do |nm|
          second_monitor = nm unless nm.laptop_lcd?
        end
        if dfp_0.connected?(self.active_monitors) &&
              !second_monitor.connected?(self.active_monitors)
          self.mode = :external
        elsif !dfp_0.connected?(self.active_monitors) &&
          second_monitor.connected?(self.active_monitors)
        self.mode = :clone
      end
    end
  end

  def get_active_monitor_list
    NvControlDpy::exec(:keyword => 'print-current-metamode').each do |line|
      if line =~ /current metamode/
        monitors = line.split(/::\s+/)[1].split(',')
        monitors.each do |m|
          self.active_monitors << m.match(/(\w+-\w+):/)[1] unless m =~ /NULL/
        end
      end
    end
  end

  # set nvidia metamode
  # params: orientation -> :right, :absolute, :clone
  def set_metamodes
    count = 0
    self.metamodes = Array.new
    self.active_monitors.each do |nm|
      pos = "+0+0"
      pos_in_array = 0
      if self.mode == :external && count == 1
        pos = "+#{self.active_monitors[0].xres}+0" if nm
      end
      self.metamodes[count] = { :type => nm.connection_type, :pos => pos }
      count += 1
    end
  end

  def set_monitor_resolution
    res = NvControlDpy::get_max_modelines(self)
    self.probed_monitors.each do |nm|
      nm.change_preferred_modeline(res[nm.connection_type.gsub('-','_').downcase.to_sym])
    end
  end

  def create_metamode_str
    a = []
    metamode = self.metamodes[0]
    a[0] = (metamode) ? "#{metamode[:type]}: nvidia-auto-select #{metamode[:pos]}" : 'NULL'
    metamode = self.metamodes[1]
    a[1] = (metamode) ? "#{metamode[:type]}: nvidia-auto-select #{metamode[:pos]}": 'NULL'
    a.join(', ')
  end

  def get_display_mask
    self.mask = NvControlDpy.get_display_mask
  end

  def get_probed_monitor_list
    self.probed_monitors = []
    NvControlDpy::get_probed_displays.each do |line|
      line.strip!
      if line =~ /\(0x\d{8}\)/
        nm = NvidiaMonitor.new
        left_split = line.strip.split(/:/)
        nm.name = left_split[1].strip
        nm.connection_type = left_split[0].split(/\s+/)[0]
        nm.mask = left_split[0].split(/\s+/)[1].match(/0x\d{8}/)[0].to_i(16)
        self.probed_monitors << nm
      end
    end
  end

  def get_active_monitor_list
    self.active_monitors = []
    NvControlDpy::exec(:keyword => 'print-current-metamode').each do |line|
      if line =~ /current metamode/
        monitors = line.split(/::\s+/)[1].split(',')
        monitors.each do |m|
          unless m =~ /NULL/
            conn_type = m.match(/(\w+-\w+):/)[1].upcase
            self.active_monitors << self.probed_monitors.find { |i|
                i.connection_type == conn_type }
          end
        end
      end
    end
  end

end
