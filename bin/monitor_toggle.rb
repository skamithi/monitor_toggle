#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../lib/nvidia_laptop_monitor'

path_to_exec = $0.split('/')
path_to_exec.pop
xosd = "/#{path_to_exec.join('/')}/xosd.sh"
`#{xosd} 'Changing Monitor Mode'`
NvidiaMonitor.change_monitor_mode
`#{xosd} '#{NvidiaMonitor.osd_str}'`
