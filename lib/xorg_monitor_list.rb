class XorgMonitorList
  attr_accessor :probed_monitors, :active_monitors, :xrandr_res, :xrandr_id,
                        :osd_str, :mode

  def initialize(options = {})
    @probed_monitors = []
    @active_monitors   = []
    @mask = 0
  end

  def run_xrandr
    if self.xrandr_res && self.xrandr_id
        `xrandr -s #{self.xrandr_res.join('x')} -r #{self.xrandr_id}`
    else
        self.osd_str = "Failed to execute xrandr"
    end
  end

end

