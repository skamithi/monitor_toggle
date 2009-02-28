require File.dirname(__FILE__) + '/../lib/nvidia_laptop_monitor'
require File.dirname(__FILE__) + '/nv_display_output'
require 'ruby-debug'

include NvControlDpy::TestOutput

describe NvidiaMonitor do
    before(:each) do

        # Reset monitor list
        NvidiaMonitor.reset

        # generate instance variables for various tests
        @monitor_lcd = NvidiaMonitor.new(:name => 'IBM',
                                                               :connection_type => 'DFP-0',
                                                               :mask => '0x1000'.to_i(16),
                                                               :xres => 1680,
                                                               :yres => 1050)
        @monitor_lcd.store

        @second_monitor = NvidiaMonitor.new(:name => 'DELL 2208WFP',
                                                                    :connection_type => 'CRT-0',
                                                                    :mask => '0x100'.to_i(16),
                                                                    :xres => 1280,
                                                                    :yres => 1050)
        @second_monitor.store

        @third_monitor = NvidiaMonitor.new(:name => 'NEC LCD203WXM',
                                                                 :connection_type => 'DFP-1',
                                                                 :mask => '0x10000'.to_i(16),
                                                                 :xres => 1920,
                                                                 :yres => 1080)
        NvidiaMonitor.active_monitors = ['dfp-0']
        # Define default display_mask. Only Laptop LCD matched
        NvidiaMonitor.display_mask = '0x1000'.to_i(16)
    end

    describe "Test Instance Members" do
        it "should says is LCD if type is DFP-0" do
            @monitor_lcd.should be_laptop_lcd
            @second_monitor.should_not be_laptop_lcd
        end

        it "should say its connected if display mask " +
            "contains mask of the monitor" do
            @monitor_lcd.should be_connected
        end
    end

    describe "Test Adding Resolutions" do

        it "should set yres => 1050 and xres to 1280 if modeline is 1280x1050" do
            @monitor_lcd.add_max_modeline("1280x1050")
            @monitor_lcd.max_resolution.should == "1280x1050"
        end

        it "should set dfp-0 resolution to '1680x1050' and " +
           "crt-0 resolution to '1280x1050' " do
            NvidiaMonitor.find("DFP-0").max_resolution.should == "1680x1050"
            NvidiaMonitor.find("CRT-0").max_resolution.should == "1280x1050"
        end
    end

    describe "Metamodes" do
        before (:each) do
            NvControlDpy.stub!(:exec).
                with(:keyword => 'print-modelines').and_return(modelines(3))
            @monitor_lcd.set_metamode(:absolute)
        end

        it "should be able to create an absolute metamode" do
            NvidiaMonitor.create_metamode_str.should ==
                                "DFP-0: nvidia-auto-select +0+0, NULL"
        end

        it "should be able to create a clone metamode" do
            @second_monitor.set_metamode(:clone)
            NvidiaMonitor.create_metamode_str.should ==
                    'DFP-0: nvidia-auto-select +0+0, CRT-0: nvidia-auto-select +0+0'
        end

        it "should be able to create a external monitor metamode" do
            @third_monitor.store
            @second_monitor.set_metamode(:absolute)
            @third_monitor.set_metamode(:right)
            NvidiaMonitor.create_metamode_str.should ==
                    'CRT-0: nvidia-auto-select +0+0, DFP-1: nvidia-auto-select +1280+0'
        end
    end

    describe "Determine Next Monitor State" do

        describe "with 1 monitor" do
            it "should return 'lcd' if there is only 1 monitor probed" do
                @second_monitor.delete
                NvidiaMonitor.send(:determine_monitor_state).should == :lcd
            end
        end

        describe "with 2 monitors" do
            it "should return 'lcd'  if both are active" do
                NvidiaMonitor.active_monitors = ['crt-0', 'dfp-0']
                #NvidiaMonitor.display_mask = '0x1100'.to_i(16)
                NvidiaMonitor.send(:determine_monitor_state).should == :lcd
            end

            it "should return 'external' if there are 1 monitor active \n " +
                "and the active monitor is laptop LCD and one connected but not active" do
                NvidiaMonitor.active_monitors = ['dfp-0']
                NvidiaMonitor.send(:determine_monitor_state).should == :external
            end

            it "should return 'clone'  if there are 1 monitor active \n " +
                "and the active monitor is not laptop LCD and one connected but not active" do
                NvidiaMonitor.active_monitors = ['crt-0']
                NvidiaMonitor.send(:determine_monitor_state).should == :clone
            end
        end

        describe "with 3 monitors" do

            before(:each) do
                @third_monitor.store
            end

            it "should return 'lcd' if both external screens are active" do
                NvidiaMonitor.active_monitors = ['dfp-1', 'crt-0']
                NvidiaMonitor.send(:determine_monitor_state).should == :lcd
            end

            it "should return 'external', if laptop LCD is active" do
                NvidiaMonitor.active_monitors = ['dfp-0']
                NvidiaMonitor.send(:determine_monitor_state).should == :external
            end
        end
    end

    describe "Set Monitor Mode" do
        before(:each) do
            NvidiaMonitor.reset
            ### define default Stubs

            #for NvControlDpy::exec
            NvControlDpy.stub!(:exec).and_return(nil)

            #for NvControlDpy::set_display_mask
            NvControlDpy.stub!(:set_display_mask).and_return(nil)
            NvidiaMonitor.stub!(:run_xrandr)
        end

        describe "using 1 monitor" do

            before (:each) do
                NvControlDpy.stub!(:exec).with(:keyword => 'probe-dpys').
                    and_return(probed_data(1))
                NvControlDpy.stub!(:exec).with(:keyword => 'get-associated-dpys').
                    and_return(current_mask(1, :lcd))
                NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                    and_return(current_metamode(1))
            end

            it "should return a LCD display mask and monitor count should be 1 "+
                "after probing and getting display mask" do
                NvidiaMonitor.send(:probe_and_get_display_mask)
                NvidiaMonitor.find(:all).size.should == 1
                NvidiaMonitor.display_mask.should == '0x10000'.to_i(16)
            end

            it "should return OSD String stating 'LCD Mode'" do
                NvidiaMonitor.change_monitor_mode
                NvidiaMonitor.osd_str.should == "LCD Mode: 1 Monitor"
            end
        end

        describe "using 2 monitors" do
            before (:each) do
                NvControlDpy.stub!(:exec).with(:keyword => "probe-dpys").
                    and_return(probed_data(2))
                NvControlDpy.stub!(:exec).
                            with(:keyword => 'print-modelines').
                                    and_return(modelines(2))
            end

            describe "and the current mode is LCD mode" do
                before(:each) do
                    current_mode = :lcd
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'get-associated-dpys').
                                and_return(current_mask(2, current_mode))
                    NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                        and_return(current_metamode(2, current_mode))
                    @mode = :external
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'print-metamodes').
                            and_return(metamodes({:num_of_monitors => 2, :mode => @mode}))
                end

                it "should return a External display mask and monitor count should "+
                   "be 2 after probing and activating" do
                    NvidiaMonitor.send(:probe_and_get_display_mask)
                    NvidiaMonitor.active_monitors = NvidiaMonitor.get_active_monitors
                    NvidiaMonitor.find(:all).size.should == 2
                    NvidiaMonitor.display_mask.should == '0x10000'.to_i(16)
                    mode = NvidiaMonitor.send(:determine_monitor_state)
                    mode.should == @mode
                    NvidiaMonitor.mode = mode
                    NvidiaMonitor.send(:activate)
                    NvidiaMonitor.display_mask.to_s(16).should == '1'
                    NvidiaMonitor.create_metamode_str.should ==
                            'CRT-0: nvidia-auto-select +0+0, NULL'
                    debugger
                    NvControlDpy.activate_metamode(NvidiaMonitor.create_metamode_str).should == '67'
                end

                it "should return OSD string stating its in External Mode" do
                    NvidiaMonitor.change_monitor_mode
                    NvidiaMonitor.xrandr_res.join('x').should == '1280x1050'
                    NvidiaMonitor.osd_str.should == "External Mode: 2 Monitors"
                end
            end

            describe "and the current mode is External" do
                before(:each) do
                    current_mode = :external
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'get-associated-dpys').
                                and_return(current_mask(2, current_mode))
                    NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                        and_return(current_metamode(2, current_mode))
                    @next_mode = :clone
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'print-metamodes').
                            and_return(metamodes({:num_of_monitors => 2, :mode => @next_mode}))
                end
                it "should return a clone display mask  and the monitor count is 2 "+
                   "after probing and activating" do
                    NvidiaMonitor.send(:probe_and_get_display_mask)
                    NvidiaMonitor.active_monitors = NvidiaMonitor.get_active_monitors
                    NvidiaMonitor.find(:all).size.should == 2
                    NvidiaMonitor.display_mask.should == '0x1'.to_i(16)
                    mode = NvidiaMonitor.send(:determine_monitor_state)
                    mode.should == @next_mode
                    NvidiaMonitor.mode = mode
                    NvidiaMonitor.send(:activate)
                    NvidiaMonitor.display_mask.to_s(16).should == '10001'
                    NvidiaMonitor.create_metamode_str.should ==
                            'DFP-0: nvidia-auto-select +0+0, CRT-0: nvidia-auto-select +0+0'
                    NvControlDpy.activate_metamode(NvidiaMonitor.create_metamode_str).should == '62'
                end

                it "should return OSD String saying its in Clone Mode" do
                    NvidiaMonitor.change_monitor_mode
                    NvidiaMonitor.xrandr_res.join('x').should == '1680x1050'
                    NvidiaMonitor.osd_str.should == "Clone Mode: 2 Monitors"
                end
            end

            describe "and the current mode is clone" do
                before(:each) do
                    current_mode = :clone
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'get-associated-dpys').
                                and_return(current_mask(2, current_mode))
                    NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                        and_return(current_metamode(2, current_mode))
                    @next_mode = :lcd
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'print-metamodes').
                            and_return(metamodes({:num_of_monitors => 2, :mode => @next_mode}))
                end
                it "should return a lcd display mask  and the monitor count is 2 "+
                   "after probing and activating" do
                    NvidiaMonitor.send(:probe_and_get_display_mask)
                    NvidiaMonitor.active_monitors = NvidiaMonitor.get_active_monitors
                    NvidiaMonitor.find(:all).size.should == 2
                    NvidiaMonitor.display_mask.should == '0x10001'.to_i(16)
                    mode = NvidiaMonitor.send(:determine_monitor_state)
                    mode.should == @next_mode
                    NvidiaMonitor.mode = mode
                    NvidiaMonitor.send(:activate)
                    NvidiaMonitor.display_mask.to_s(16).should == '10000'
                    NvidiaMonitor.create_metamode_str.should ==
                            'DFP-0: nvidia-auto-select +0+0, NULL'
                    NvControlDpy.activate_metamode(NvidiaMonitor.create_metamode_str).should == '68'
                end

                it "should return OSD String saying its in LCD Mode" do
                    NvidiaMonitor.change_monitor_mode
                    NvidiaMonitor.xrandr_res.join('x').should == '1680x1050'
                    NvidiaMonitor.osd_str.should == "LCD Mode: 2 Monitors"
                end
            end
        end
        describe "with 3 monitors" do
            before (:each) do
                NvControlDpy.stub!(:exec).with(:keyword => "probe-dpys").
                    and_return(probed_data(3))
                NvControlDpy.stub!(:exec).
                            with(:keyword => 'print-modelines').
                            and_return(modelines(3))
            end
              describe "and the current mode is LCD mode" do
                before(:each) do
                    current_mode = :lcd
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'get-associated-dpys').
                                and_return(current_mask(3, current_mode))
                    NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                        and_return(current_metamode(2, current_mode))
                    @next_mode = :external
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'print-metamodes').
                        and_return(metamodes({:num_of_monitors => 3, :mode => @next_mode}))
                end

                it "should return a external display mask  and the monitor count is 3 "+
                   "after probing and activating" do
                    NvidiaMonitor.send(:probe_and_get_display_mask)
                    NvidiaMonitor.active_monitors = NvidiaMonitor.get_active_monitors
                    NvidiaMonitor.find(:all).size.should == 3
                    NvidiaMonitor.display_mask.to_s(16).should == '10000'
                    mode = NvidiaMonitor.send(:determine_monitor_state)
                    mode.should == @next_mode
                    NvidiaMonitor.mode = mode
                    NvidiaMonitor.send(:activate)
                    NvidiaMonitor.display_mask.to_s(16).should == '20001'
                    NvidiaMonitor.create_metamode_str.should ==
                            'CRT-0: nvidia-auto-select +0+0, DFP-1: nvidia-auto-select +1280+0'
                    NvControlDpy.activate_metamode(NvidiaMonitor.create_metamode_str).should == '63'
                end

                it "should return OSD String saying its in External Mode" do
                    NvidiaMonitor.change_monitor_mode
                    NvidiaMonitor.xrandr_res.join('x').should == '3200x1088'
                    NvidiaMonitor.osd_str.should == "External Mode: 3 Monitors"
                end
            end

            describe "and the current mode is External mode" do
                before(:each) do
                    current_mode = :external
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'get-associated-dpys').
                                and_return(current_mask(3, current_mode))
                    NvControlDpy.stub!(:exec).with(:keyword =>'print-current-metamode').
                        and_return(current_metamode(2, current_mode))
                    @next_mode = :lcd
                    NvControlDpy.stub!(:exec).
                        with(:keyword => 'print-metamodes').
                        and_return(metamodes({:num_of_monitors => 3, :mode => @next_mode}))
                end

                it "should return a external display mask  and the monitor count is 3 "+
                   "after probing and activating" do
                    NvidiaMonitor.send(:probe_and_get_display_mask)
                    NvidiaMonitor.active_monitors = NvidiaMonitor.get_active_monitors
                    NvidiaMonitor.find(:all).size.should == 3
                    NvidiaMonitor.display_mask.to_s(16).should == '20001'
                    mode = NvidiaMonitor.send(:determine_monitor_state)
                    mode.should == @next_mode
                    NvidiaMonitor.mode = mode
                    NvidiaMonitor.send(:activate)
                    NvidiaMonitor.display_mask.to_s(16).should == '10000'
                    NvidiaMonitor.create_metamode_str.should ==
                            'DFP-0: nvidia-auto-select +0+0, NULL'
                    NvControlDpy.activate_metamode(NvidiaMonitor.create_metamode_str).should == '61'
                end

                it "should return OSD String saying its in External Mode" do
                    NvidiaMonitor.change_monitor_mode
                    NvidiaMonitor.xrandr_res.join('x').should == '1680x1050'
                    NvidiaMonitor.osd_str.should == "LCD Mode: 3 Monitors"
                end
            end
        end
    end

end
