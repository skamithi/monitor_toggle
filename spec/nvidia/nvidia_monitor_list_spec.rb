require File.dirname(__FILE__) + '/../support/env.rb'
require File.dirname(__FILE__) + '/../../lib/nvidia/nvidia_monitor_list'
require File.dirname(__FILE__) + '/nv_display_output'
require File.dirname(__FILE__) + '/../support/nvidia_monitor_helpers'

include NvControlDpy::TestOutput
include SpecHelpers

describe NvidiaMonitorList do
  before(:each) do
    @laptop_lcd = NvidiaMonitor.new(:name => 'IBM',
                                                          :connection_type => 'DFP-0',
                                                          :mask => '0x10000'.to_i(16))

    @second_monitor = NvidiaMonitor.new(:name => 'DELL 2208WFP',
                                                                    :connection_type => 'CRT-0',
                                                                    :mask => '0x1'.to_i(16))

    @third_monitor = NvidiaMonitor.new(:name => 'NEC LCD203WXM',
                                                              :connection_type => 'DFP-1',
                                                              :mask => '0x20000'.to_i(16))
    @monitor_list = NvidiaMonitorList.new"associated display device mask: 0x00000001"
    NvControlDpy.stub!(:set_display_mask).and_return(nil)
  end

  describe "Monitor Probe" do

    (1..3).each do |i|
      it "should return a count of #{i} when #{i} #{monitor_singular_or_plural(i)} present " do
        NvControlDpy.stub!(:exec).with(:keyword => 'probe-dpys').
            and_return(probed_data(i))
        @monitor_list.send(:get_probed_monitor_list)
        @monitor_list.probed_monitors.size.should == i
      end
    end

  end

  describe "Active Monitor count" do

    (1..3).each do |i|
      it "should be #{i} when #{i} #{monitor_singular_or_plural(i)}  active" do
        NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                    and_return(current_metamode(i, display_mode(i)))
        @monitor_list.send(:get_active_monitor_list)
        monitor_size = (i > 2)? 2 : i
        @monitor_list.active_monitors.size.should == monitor_size
      end
    end
  end

  describe "Display Mask" do
    (1..3).each do |i|
      it "should be #{display_mask(i)} if #{i} #{monitor_singular_or_plural(i)} is connected" do
        NvControlDpy.stub!(:exec).with(:keyword => 'get-associated-dpys').
                and_return(current_mask(i, display_mode(i)))
        @monitor_list.send(:get_display_mask)
        @monitor_list.mask.to_s(16).should == display_mask(i)
      end
    end
  end


  describe "Get Next Monitor Mode" do

    describe "with 1  monitor" do

      it "should return :lcd if there is only 1 monitor probed" do
        @monitor_list.probed_monitors = [@laptop_lcd]
        @monitor_list.active_monitors = [@laptop_lcd]
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.mode.should == :lcd
      end

    end

    describe "with 2 monitors" do

      before(:each) do
        @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor]
      end

      it "should return :lcd if both monitors are active" do
        @monitor_list.active_monitors = [@laptop_lcd, @second_monitor]
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.mode.should == :lcd
      end

      it "should return :external if there is 1 monitor active " +
        "and the active monitor is the laptop LCD" do
        @monitor_list.active_monitors = [@laptop_lcd]
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.mode.should == :external
      end

      it "should return :clone if there is 1 monitor active " +
        "and the active monitor is not the laptop LCD" do
        @monitor_list.active_monitors = [@second_monitor]
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.mode.should == :clone
      end

    end

    describe "with 3 monitors" do
      before(:each) do
        @monitor_list.probed_monitors =
            [@laptop_lcd, @second_monitor, @third_monitor]
      end

      it "should return :lcd if both external monitors are active" do
        @monitor_list.active_monitors = [@second_monitor, @third_monitor]
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.mode.should == :lcd
      end

      it "should return :external if only the laptop LCD is active" do
        @monitor_list.active_monitors = [@laptop_lcd]
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.mode.should == :external
      end

    end

  end

  describe "Set Monitor Resolutions" do
    before(:each) do
      NvControlDpy.stub!(:exec).
                with(:keyword => 'print-modelines').and_return(modelines(3))
      @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor, @third_monitor]
      @monitor_list.send(:set_monitor_resolution)
    end
    it "should return '1600x1200' for the laptop lcd" do
      @laptop_lcd.resolution.should == '1680x1050'
    end
    it "should return '1280x1050' for the 2nd monitor" do
      @second_monitor.resolution.should == '1280x1050'
    end
    it "should return '1900x1088' for the 3rd monitor" do
      @third_monitor.resolution.should == '1920x1088'
    end
  end

  describe "Activation" do
    before(:each) do
      NvControlDpy.stub!(:exec).
                with(:keyword => 'print-modelines').and_return(modelines(3))
      NvControlDpy.stub!(:exec).
                        with(:keyword => 'get-associated-dpys').
                                and_return("associated display device mask: 0x00030001")
    end

    describe "where only 1 probed monitor exists" do
      it "should return a display mask of 0x1000" do
        @monitor_list.probed_monitors = [@laptop_lcd]
        @monitor_list.active_monitors = [@laptop_lcd]
        @monitor_list.send(:set_monitor_resolution)
        @monitor_list.send(:get_next_monitor_mode)
        @monitor_list.send(:activate_monitors)
        @monitor_list.mode.should == :lcd
        @monitor_list.mask.to_s(16).should == '10000'
        @monitor_list.active_monitors.should == [@laptop_lcd]
        @monitor_list.xrandr_res.should == [1680, 1050]
      end
    end

    describe "where 2 probed monitors exists" do
      before(:each) do
        @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor]
        @monitor_list.send(:set_monitor_resolution)
      end

      describe "and the active monitor is the laptop LCD" do
        it "should return a mode of :external" do
          @monitor_list.active_monitors = [@laptop_lcd]
          @monitor_list.send(:get_next_monitor_mode)
          @monitor_list.send(:activate_monitors)
          @monitor_list.mode.should == :external
          @monitor_list.mask.to_s(16).should == '1'
          @monitor_list.active_monitors.should == [@second_monitor]
          @monitor_list.xrandr_res.should  == [1280, 1050]
        end
      end

      describe "and the active monitor is the external" do
        it "should return a mode of :clone" do
          @monitor_list.active_monitors = [@second_monitor]
          @monitor_list.send(:get_next_monitor_mode)
          @monitor_list.send(:activate_monitors)
          @monitor_list.mode.should == :clone
          @monitor_list.mask.to_s(16).should == '10001'
          @monitor_list.active_monitors == [@laptop_lcd, @second_monitor]
          @monitor_list.xrandr_res.should  == [1680, 1050]
        end
      end

      describe "and the monitors are in clone mode" do
        it "should return a mode of :lcd" do
          @monitor_list.active_monitors = [@laptop_lcd, @second_monitor]
          @monitor_list.send(:get_next_monitor_mode)
          @monitor_list.send(:activate_monitors)
          @monitor_list.mode.should == :lcd
          @monitor_list.mask.to_s(16).should == '10000'
          @monitor_list.active_monitors.should == [@laptop_lcd]
          @monitor_list.xrandr_res.should  == [1680,1050]
        end
      end

    end

    describe "where 3 probed monitors exist" do

      before(:each) do
        @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor, @third_monitor]
        @monitor_list.send(:set_monitor_resolution)
      end

      describe "and the active monitor is the laptop LCD" do
        it "should return a mode of :external" do
          @monitor_list.active_monitors = [@laptop_lcd]
          @monitor_list.send(:get_next_monitor_mode)
          @monitor_list.send(:activate_monitors)
          @monitor_list.mode.should == :external
          @monitor_list.mask.to_s(16).should == '20001'
          @monitor_list.active_monitors.should == [@second_monitor, @third_monitor]
          @monitor_list.xrandr_res.should == [3200, 1088]
        end
      end

      describe "and the active monitors are the 2 external monitors" do
        it "should return a mode of :lcd" do
          @monitor_list.active_monitors = [@second_monitor, @third_monitor]
          @monitor_list.send(:get_next_monitor_mode)
          @monitor_list.send(:activate_monitors)
          @monitor_list.mode.should == :lcd
          @monitor_list.mask.to_s(16).should == '10000'
          @monitor_list.active_monitors.should == [@laptop_lcd]
          @monitor_list.xrandr_res.should == [1680, 1050]
        end
      end
    end

  end

  describe "Metamode string" do
    before(:each) do
      NvControlDpy.stub!(:exec).
            with(:keyword => 'print-modelines').and_return(modelines(3))
    end

    describe "for 1 monitor" do
      before(:each) do
        @monitor_list.probed_monitors = [@laptop_lcd]
        @monitor_list.active_monitors = [@laptop_lcd]
        @monitor_list.send(:set_monitor_resolution)
      end

      it "should be 'DFP-0: nvidia-auto-select +0+0' " do
        @monitor_list.send(:set_metamodes)
        @monitor_list.send(:create_metamode_str).should == 'DFP-0: nvidia-auto-select +0+0, NULL'
      end

    end

    describe "for 2 monitors" do

      before(:each) do
        @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor]
      end

      describe "in clone mode" do
        it "should be  'DFP-0: nvidia-auto-select +0+0, " +
          "CRT-0: nvidia-auto-select +0+0' " do
          @monitor_list.active_monitors = [@laptop_lcd, @second_monitor]
          @monitor_list.send(:set_metamodes)
          @monitor_list.send(:create_metamode_str).should ==
                      'DFP-0: nvidia-auto-select +0+0, ' +
                      'CRT-0: nvidia-auto-select +0+0'
        end
      end

      describe "in external mode" do
        it "should be 'CRT-0: nvidia-auto-select +0+0, NULL' " do
          @monitor_list.active_monitors = [@second_monitor]
          @monitor_list.send(:set_metamodes)
          @monitor_list.send(:create_metamode_str).should ==
              'CRT-0: nvidia-auto-select +0+0, NULL'
        end
      end

      describe "in lcd mode" do
        it "should  be 'DFP-0: nvidia-auto-select +0+0, NULL' " do
            @monitor_list.active_monitors = [@laptop_lcd]
            @monitor_list.send(:set_metamodes)
            @monitor_list.send(:create_metamode_str).should ==
                'DFP-0: nvidia-auto-select +0+0, NULL'
        end
      end

    end

    describe "for 3 monitors" do
      before(:each) do
        @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor, @third_monitor]
      end

      describe "in external mode" do

        before(:each) do
          @monitor_list.active_monitors = [@second_monitor, @third_monitor]
          @monitor_list.send(:set_metamodes)
        end

        it "should be 'CRT-0: nvidia-auto-select +0+0, DFP-1: nvidia-auto-select +0+0' " do
          @monitor_list.send(:create_metamode_str).should ==
            'CRT-0: nvidia-auto-select +0+0, DFP-1: nvidia-auto-select +0+0'
        end

      end

      describe "in lcd mode" do

        before(:each) do
          @monitor_list.active_monitors = [@laptop_lcd]
          @monitor_list.send(:set_metamodes)
        end

        it "should be 'DFP-0: nvidia-auto-select +0+0, NULL' " do
          @monitor_list.send(:create_metamode_str).should ==
            'DFP-0: nvidia-auto-select +0+0, NULL'
        end

      end

    end

  end

end
