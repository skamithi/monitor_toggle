task :uninstall do
    err_msg =  running_as_root
    if (err_msg.empty?)
        acpi_script = '/etc/acpi/toggle_monitor.sh'
        install_dir = ''
        if File.exists?(acpi_script)
            File.readlines(acpi_script).each do |line|
                if line =~ /(.*)\/bin\/monitor_toggle.rb/
                    install_dir = $1.clone.strip
                    break
                end
            end
            puts_with_arrow("Removing #{acpi_script}")
            FileUtils.rm acpi_script
        end
        acpi_event_script = '/etc/acpi/events/ibm-videobtn'
        if File.exists?(acpi_event_script)
            ChangeOnFile(acpi_event_script, /action=.*/, "action=true")
            puts_with_arrow("Restoring #{acpi_event_script} back to the default config")
        end
        if File.directory?(install_dir)
            puts_with_arrow("Removing #{install_dir}")
            FileUtils.rm_r install_dir
        end

        RestartAcpid()

        nv_control_dpy_path = '/usr/local/bin/nv-control-dpy'
        if File.exists?(nv_control_dpy_path)
            FileUtils.rm nv_control_dpy_path
            puts_with_arrow "Removing nv-control-dpy"
        end
    else
        puts err_msg
    end
end


task :install, :install_dir do |t, args|

  # Default location for installation is /usr/local/monitor_toggle
  home_dir = ENV['HOME']
  install_dir = "/usr/local/monitor_toggle/"

  if args.install_dir
    install_dir = args.install_dir
    install_dir += '/' if args.install_dir !~ /\/$/ # add trailing / if missing
  end
  success = false
  err_msg = nil
  err_msg = check_dependencies

  if err_msg.empty?
     unless File.directory?(install_dir)
         puts_with_arrow("Creating #{install_dir}")
         FileUtils.mkdir_p install_dir
    end

    puts_with_arrow("Copy files to  #{install_dir}")
    FileUtils.cp_r %w{lib/ spec/ bin/ README TODO} , install_dir
    FileUtils.chmod_R 0755, install_dir + 'bin'


    acpi_dir = '/etc/acpi/'
    acpi_script_contents =
<<EOF
#!/bin/bash
test -f /usr/share/acpi-support/key-constants || exit 0

. /etc/default/acpi-support
. /usr/share/acpi-support/power-funcs

for x in /tmp/.X11-unix/*; do
    displaynum=`echo $x | sed s#/tmp/.X11-unix/X##`
    getXuser;
    if [ x"$XAUTHORITY" != x"" ]; then
        export DISPLAY=":$displaynum"
        #{install_dir}bin/monitor_toggle.rb
    fi
 done

EOF

    if File.directory?(acpi_dir) && File.directory?("#{acpi_dir}/events")
        puts_with_arrow("Copy acpi scripts to acpi directory")
        acpi_script = acpi_dir + 'toggle_monitor.sh'
        f = File.new(acpi_script,'w')
        f.puts acpi_script_contents
        f.close
        FileUtils.chown 'root', 'root',  acpi_script
        FileUtils.chmod 0755, acpi_script
        puts_with_arrow("Modify ibm-videobtn script in acpi directory")
        acpi_event_script = '/etc/acpi/events/ibm-videobtn'
        ChangeOnFile(acpi_event_script, /action=.*/, "action=#{acpi_script}")
    end
    InstallNvControlDpy()
    RestartAcpid()
  else
    puts err_msg
  end
end

def ChangeOnFile(file, regex_to_find, text_to_put_in_place)
  text= File.read file
  File.open(file, 'w+'){|f| f << text.gsub(regex_to_find,
                text_to_put_in_place)}
end

def RestartAcpid
    acpid_init_script = '/etc/init.d/acpid'
     if File.exists?(acpid_init_script)
         puts_with_arrow("Restarting ACPID")
         `#{acpid_init_script} restart`
     else
         puts_with_arrow("Failed to Find ACPID init script. Manually restart ACPID")
     end
end

def running_as_root
    err_msg = ''
    if ENV['USER'] != 'root'
        err_msg = "** Installation must be done as root \n"
    end
    err_msg
end

def InstallNvControlDpy
    puts_with_arrow("Installing nv-control-dpy")
    nvidia_settings_dir = 'nvidia-settings-177.78'
    `tar xvfj #{nvidia_settings_dir}_source.tar.bz2`
    Dir.chdir(nvidia_settings_dir + '/samples')
    `make`
    FileUtils.mkdir_p '/usr/local/bin'
    FileUtils.cp 'nv-control-dpy' , '/usr/local/bin'
    FileUtils.chmod 0755, '/usr/local/bin/nv-control-dpy'
    puts_with_arrow("Successfully installed nv-control-dpy")
end

def CheckForNvidiaCard
    `lspci`.each do |l|
        return true if l.match(/.*\s+VGA\s+.*(nVidia).*/)
    end
    false
end

def check_dependencies
  err_msg = ''
  # make sure to run as root
  err_msg += running_as_root

  # Check that graphics card is Nvidia
  unless CheckForNvidiaCard()
    err_msg += "** Video Card is not Nvidia. Tool only works with Nvidia video cards"
  end
  unless File.exists?('/usr/bin/osd_cat')
    err_msg += "** xosd package is not installed. Please install it \n"
  end

  unless File.exists?('/etc/acpi/events/ibm-videobtn')
    err_msg +="** cannot find the ibm-videobtn event script. " +
                    "Either Acpid is not installed or the script does not exist \n"
  end

  err_msg
end

def puts_with_arrow(msg)
   puts "=> #{msg} \n"
end
