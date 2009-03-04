#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/nvidia/nvidia_monitor_list'

xosd = File.dirname(__FILE__) + '/xosd.sh'
`#{xosd} 'Changing Monitor Mode'`
monitor_list = NvidiaMonitorList.new
monitor_list.change_monitor_mode
`#{xosd} '#{monitor_list.osd_str}'`
