require File.dirname(__FILE__) + '/support/env.rb'

describe XorgMonitor do
  before(:each) do
    @monitor_lcd = XorgMonitor.new(:name => 'IBM',
                                                          :connection_type => 'DFP-0',
                                                          :xres => 1680,
                                                          :yres => 1050)
    @second_monitor = XorgMonitor.new(:name => 'NEC LCD203WXM',
                                                                 :connection_type => 'DFP-1',
                                                                 :xres => 1920,
                                                                 :yres => 1080)
  end

  it "should be the laptop LCD if the connection type is 'DFP-0' " do
    @monitor_lcd.should be_laptop_lcd
    @second_monitor.should_not be_laptop_lcd
  end

  it "should be connected if the monitor is in the active monitor list" do
    active_monitors = [@monitor_lcd]
    @monitor_lcd.should be_connected(active_monitors)
    @second_monitor.should_not be_connected(active_monitors)
  end

  describe 'resolution when changed' do

    it "should be '1280x1050'  if successful " do
            @monitor_lcd.change_preferred_modeline('1280x1050')
            @monitor_lcd.resolution.should == '1280x1050'
    end

    it "should be '1680x1050' (unchanged) if unsuccessful" do
      @monitor_lcd.change_preferred_modeline('12x12232')
      @monitor_lcd.resolution.should == '1680x1050'
    end

  end
end
