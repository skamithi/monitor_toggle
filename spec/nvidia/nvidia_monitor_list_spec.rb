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
    @monitor_list = NvidiaMonitorList.new
    @monitor_list.stub!(:run_xrandr)



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
    end
    describe "and each monitor is different" do
      before(:each)do
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

    describe "and the 2 external monitors are the same" do
      before(:each) do
        @second_monitor = NvidiaMonitor.new(:name => 'NEC LCD203WXM',
                                                                    :connection_type => 'CRT-0',
                                                                    :mask => '0x1'.to_i(16))
        @monitor_list.probed_monitors = [@laptop_lcd, @second_monitor, @third_monitor]
        @monitor_list.send(:set_monitor_resolution)
      end
       it "should return '1600x1200' for the laptop lcd" do
        @laptop_lcd.resolution.should == '1680x1050'
      end
      it "should return '1920x1088' for the 2nd monitor" do
        @second_monitor.resolution.should == '1920x1088'
      end
      it "should return' '1920x1088' for the 3rd monitor" do
        @third_monitor.resolution.should == '1920x1088'
      end
    end
  end

  describe "Activation" do
    before(:each) do
      NvControlDpy.stub!(:exec).
                with(:keyword => 'print-modelines').and_return(modelines(3))
      NvControlDpy.stub!(:set_display_mask).and_return(nil)
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

  describe "Do monitor mode change" do
    describe "for 1 monitor" do
      before(:each) do
        current_mode = :lcd
        # for probe monitor  add stub for NvControlDpy probe-dpys
        NvControlDpy.stub!(:exec).with(:keyword => 'probe-dpys').
                    and_return(probed_data(1))
        # for active monitor  add stub for NvControlDpy print-current-metamode
        NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                        and_return(current_metamode(1, current_mode))
        NvControlDpy.should_receive(:set_display_mask).with('0x00010000')
        NvControlDpy.should_receive(:exec).with(:keyword => 'print-modelines').
                    and_return(modelines(1))
         NvControlDpy.should_receive(:exec).
            with({:keyword => 'add-metamode', :arg => 'DFP-0: nvidia-auto-select +0+0, NULL'}, true)
          NvControlDpy.should_receive(:exec).
                  with(:keyword => 'print-metamodes').
                 and_return(metamodes({:num_of_monitors => 1, :mode => :lcd }))

      end
      it "should do nothing and turn an OSD string stating its in LCD mode" do
          @monitor_list.change_monitor_mode
          @monitor_list.xrandr_res.should == [1680, 1050]
          @monitor_list.osd_str.should == "LCD Mode: 1 Monitor"
      end
    end

      @monitor_test_hash = {
        :lcd_2_mon =>{ :next_mode => :external, :xrandr_res => '1280x1050',
                      :display_mask => '0x00010001',
                      :metamode_str => 'CRT-0: nvidia-auto-select +0+0, NULL',
                      :osd_str => 'External Mode: 2 Monitors',
                      :mon_count => 2,
                      :current_mode => :lcd,
                      :active_mon_count => 1,
                      :xrandr_id => '67'},
        :external_2_mon => { :next_mode => :clone, :xrandr_res => '1680x1050',
                      :display_mask => '0x00010001',
                      :metamode_str => 'DFP-0: nvidia-auto-select +0+0, CRT-0: nvidia-auto-select +0+0',
                      :osd_str => 'Clone Mode: 2 Monitors',
                      :mon_count => 2,
                      :current_mode => :external,
                      :active_mon_count => 2,
                      :xrandr_id => '64'},
        :clone_2_mon => { :next_mode => :lcd, :xrandr_res => '1680x1050',
                      :display_mask => '0x00010001',
                      :full_mask => '10000',
                      :metamode_str => 'DFP-0: nvidia-auto-select +0+0, NULL',
                      :osd_str => 'LCD Mode: 2 Monitors',
                      :mon_count => 2,
                      :current_mode => :clone,
                      :active_mon_count => 1,
                      :xrandr_id => '50'},

          :lcd_3_mon => { :next_mode => :external, :xrandr_res => '3200x1088',
                      :display_mask => '0x00030001',
                      :metamode_str => 'CRT-0: nvidia-auto-select +0+0, DFP-1: nvidia-auto-select +1280+0',
                      :osd_str => 'External Mode: 3 Monitors',
                      :mon_count => 3,
                      :current_mode => :lcd,
                      :active_mon_count => 2,
                      :xrandr_id => '63'},

            :external_3_mon => { :next_mode => :lcd, :xrandr_res => '1680x1050',
                      :display_mask => '0x00030001',
                      :metamode_str => 'DFP-0: nvidia-auto-select +0+0, NULL',
                      :osd_str => 'LCD Mode: 3 Monitors',
                      :mon_count => 3,
                      :current_mode => :external,
                      :active_mon_count => 1,
                      :xrandr_id => '50'},
    }
    @monitor_test_hash.each do |key, value|
      describe "For #{value[:mon_count]} monitors" do

        before(:each) do
          # for probe monitor add stub for NvControl probe-dpys
          NvControlDpy.should_receive(:exec).with(:keyword => 'probe-dpys').
                    and_return(probed_data(value[:mon_count]))
          # modelines for getting resolutions
          NvControlDpy.should_receive(:exec).with(:keyword => 'print-modelines').
                    and_return(modelines(value[:mon_count]))

        end

        describe "in #{value[:current_mode]} mode" do
          before(:each) do
            NvControlDpy.stub!(:exec).with(:keyword => 'print-current-metamode').
                and_return(current_metamode(value[:mon_count], value[:current_mode]))
            NvControlDpy.should_receive(:set_display_mask).with(value[:display_mask])
            NvControlDpy.should_receive(:exec).with({:keyword => 'add-metamode', :arg => value[:metamode_str]}, true)
          NvControlDpy.stub!(:exec).
                        with(:keyword => 'print-metamodes').
                            and_return(metamodes({:num_of_monitors => value[:mon_count], :mode => value[:next_mode]}))

          end

          it "should return a mode of #{value[:next_mode]}" do
            @monitor_list.change_monitor_mode
            @monitor_list.active_monitors.size.should == value[:active_mon_count]
            @monitor_list.mode.should == value[:next_mode]
            @monitor_list.send(:create_metamode_str).should == value[:metamode_str]
            @monitor_list.mask.should == value[:display_mask].to_i(16)
            @monitor_list.xrandr_res.join('x').should == value[:xrandr_res]
            @monitor_list.xrandr_id.should == value[:xrandr_id]
            mode = (value[:next_mode] == :lcd)? 'LCD' : value[:next_mode].to_s.capitalize
            @monitor_list.osd_str.should == "#{mode} Mode: #{value[:mon_count]} Monitors"
          end
        end
      end
  end

  end
end

