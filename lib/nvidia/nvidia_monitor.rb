require File.dirname(__FILE__) + '/nv_control_dpy'
require File.dirname(__FILE__) + '/../xorg_monitor'

class NvidiaMonitor < XorgMonitor

  include NvControlDpy
  attr_accessor :mask

  def initialize(options = {})
    @mask = options[:mask]
    super
  end


# set nvidia metamode
    # params: orientation -> :right or :absolute, :clone
    # params: first_monitor listed in metamode
    def set_metamode(orientation, first_monitor = nil)
      metamode_has = new Hash
      pos = "+0+0"
      case orientation
      when :right
        pos = "+#{first_monitor.xres}+0" if first_monitor
        pos_in_array = 1
      when :clone
        pos_in_array = 1
      else
        pos_in_array = 0
      end
      metamode_hash[pos_in_array] = { :type => self.connection_type, :pos => pos }
  end
end
