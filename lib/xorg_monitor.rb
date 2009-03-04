# This class is the root class LaptopMonitors
# defines common attributes used by these 2 classes
class XorgMonitor
  attr_accessor :name, :connection_type, :xres, :yres

  def initialize(options = {})
    @name = options[:name]
    @connection_type = options[:connection_type]
    @xres = options[:xres]
    @yres = options[:yres]
  end

  # True if it is the laptop LCD
  def laptop_lcd?
    return self.connection_type == 'DFP-0'
  end

  # True if this monitor is active and displaying
  # requires a array of connection types of the active monitors
  def connected?(active_monitor_list = [])
    active_monitor_list.each do |laptop_mon|
      return true if laptop_mon.connection_type == self.connection_type
    end
    return false
  end

  # Takes a string of [x resolution]x[y resolution]
  # eg. "1680x1050" and updates xres and yres
  def change_preferred_modeline(modeline = '')
    if modeline =~ /^\d{3,4}x\d{3,4}$/
      self.xres, self.yres = modeline.split(/x/)
    end
  end

  # return the preferred resolution allowed the monitor
  def resolution
    [self.xres, self.yres].join('x')
  end

end
