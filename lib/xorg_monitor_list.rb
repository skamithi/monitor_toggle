class XorgMonitorList
  attr_accessor :probed_monitors, :active_monitors, :xrandr_res, :xrandr_id,
                        :osd_str, :mode

  def initialize(options = {})
    @probed_monitors = []
    @active_monitors   = []
  end

  def run_xrandr
    `xrandr -s #{self.xrandr_res} -r #{xrandr_id}`
  end

end
