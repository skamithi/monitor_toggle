# Defines the static output produced by the nv-control-dpy
# This is used by the spec file

module NvControlDpy

module TestOutput

# Define the Modelines
@@modelines_1st_monitor =
<<EOF
   Modelines for IBM:
  source=edid :: "nvidia-auto-select"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
  source=edid :: "1680x1050"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
  source=edid :: "1680x1050_60"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
EOF

@@modelines_2nd_monitor =
<<EOF
Modelines for DELL 2208WFP:
  source=edid :: "nvidia-auto-select"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
  source=edid :: "1280x1050"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
  source=edid :: "1280x1050_60"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync

EOF

@@modelines_3rd_monitor =
<<EOF
Modelines for NEC LCD203WXM:
  source=edid :: "nvidia-auto-select"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
  source=edid :: "1920x1088"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
  source=edid :: "1920x1088_60"  120.600  1680 1712 1760 1888  1050 1051 1054 1065  -HSync -VSync
EOF


# Define the Probed data
@@probed_data =
<<EOF
Using NV-CONTROL extension 1.17 on :0.0
Connected Display Devices:
  CRT-0 (0x00000001): DELL 2208WFP
  DFP-0 (0x00010000): IBM
  DFP-1 (0x00020000): NEC LCD203WXM

Display Device Probed Information:

  number of GPUs: 1
  display devices on GPU-0 (Quadro FX 570M):
EOF

# Define Metamodes
@@metamodes =
<<EOF
MetaModes:
  id=50, switchable=yes, source=xconfig :: DFP-0: nvidia-auto-select @1680x1050 +0+0, CRT-0: NULL, DFP-1: NULL
  id=51, switchable=yes, source=xconfig :: DFP-0: nvidia-auto-select @1680x1050 +0+0, CRT-0: NULL

EOF

# Define current metamode
@@current_metamode =
<<EOF
Using NV-CONTROL extension 1.17 on :0.0
Connected Display Devices:
  DFP-0 (0x00010000): IBM

EOF

    #print current metamode
    def current_metamode(num_of_monitors, mode = nil)

        current_metamode = @@current_metamode
        if num_of_monitors == 1
            current_metamode += 'current metamode: "id=51, switchable=yes, '+
                        'source=xconfig :: DFP-0: nvidia-auto-select @1680x1050 +0+0'
        elsif num_of_monitors == 2
            if mode == :external
                current_metamode += 'current metamode: "id=52, switchable=yes, '+
                        'source=xconfig :: CRT-0: nvidia-auto-select @1680x1050 +0+0, ' +
                        'DFP-0: NULL'
            elsif mode == :clone
                current_metamode += 'current metamode: "id=53, switchable=yes, '+
                        'source=xconfig :: CRT-0: nvidia-auto-select @1680x1050 +0+0, ' +
                        'DFP-0: nvidia-auto-select @1680x1050 +0+0'
            elsif mode == :lcd
                current_metamode += 'current metamode: "id=52, switchable=yes, '+
                    'source=xconfig :: DFP-0: nvidia-auto-select @1680x1050 +0+0, ' +
                    'CRT-0: NULL'
            end
        elsif num_of_monitors == 3
            if mode == :external
                current_metamode += 'current metamode: "id=54, switchable=yes, '+
                        'source=xconfig :: CRT-0: nvidia-auto-select @1680x1050 +0+0, ' +
                        'DFP-1: nvidia-auto-select @1680x1050 +1680+0, DFP-0: NULL'
            elsif mode == :lcd
                current_metamode +=  'current metamode: "id=55, switchable=yes, '+
                        'source=xconfig :: DFP-0: nvidia-auto-select @1680x1050 +0+0, ' +
                        'DFP-1: NULL, DFP-0: NULL'
            end
        end
        current_metamode
    end

    # Print modelines.
    # Argument: <em>num_of_monitors</em>
    def modelines(num_of_monitors)
        modelines = @@modelines_1st_monitor

        (1..2).each do |i|
            if num_of_monitors > i
                i += 1
                modelines += eval "@@modelines_#{i.ordinal}_monitor"
            end
        end

        modelines
    end

    # Print monitors probed. Number of monitors can be from 1..3
    def probed_data(num_of_monitors)
        if (num_of_monitors < 0 || num_of_monitors > 3)
            return nil
        end

        probed_data = @@probed_data

        if (num_of_monitors > 0)
            probed_data += "DFP-0 (0x00010000): IBM\n"
        end

        if (num_of_monitors > 1)
            probed_data += "CRT-0 (0x00000001): DELL 2208WFP\n"
        end

        if (num_of_monitors > 2)
            probed_data += "DFP-1 (0x00020000): NEC LCD203WXM\n"
        end

        probed_data
    end

    # Print metamode. Options are:
    # options[:first_monitor] => metamode for first monitor
    # options[:second_monitor] => metamode for 2nd monitor
    # option value can be 'NULL'
    def metamodes(options = {})
        metamode = @@metamodes
        num_of_monitors = options[:num_of_monitors]
        mode = options[:mode]
        if (num_of_monitors == 2)
          metamode << "id=67,  switchable=no, source=nv-control :: CRT-0: nvidia-auto-select @1280x1050 +0+0, NULL\n"
          metamode << "id=64, switchable=no, source=nv-control :: CRT-0: nvidia-auto-select @1280x1050 +0+0, DFP-0: nvidia-auto-select @1680x1050 +0+0\n"
        elsif (num_of_monitors == 3)
            metamode << "id=63, switchable=no, source=nv-control :: DFP-1: nvidia-auto-select @1680x1050 +1280+0, CRT-0: nvidia-auto-select @1280x1080 +0+0\n"
            metamode << "id=67,  switchable=no, source=nv-control :: CRT-0: nvidia-auto-select @1280x1050 +0+0, NULL\n"
        end
        metamode
    end

    # print newly defined device mask from running --set-associated-dpy
    def new_mask(mask)
        current_mask
        case(num_of_monitors)
            when 1
                "associated display device mask: #{mask}"
            when 2
                "associated display device mask: #{mask}"
            when 3
                "associated display device mask: #{mask}"
        end
    end

    def current_mask(num_of_monitors, mode)
        case(num_of_monitors)
            when 2
                if (mode == :external)
                     return "associated display device mask: 0x00000001"
                elsif (mode == :clone)
                    return "associated display device mask: 0x00010001"
                end
            when 3
                if (mode == :external)
                    return "associated display device mask: 0x00020001"
                end
        end
        return "associated display device mask: 0x00010000"
    end

end
end

## Define printing of ordinals for the Numeric class
class Numeric
  def ordinal
    cardinal = self.to_i.abs
    if (10...20).include?(cardinal) then
      cardinal.to_s << 'th'
    else
      cardinal.to_s << %w{th st nd rd th th th th th th}[cardinal % 10]
    end
  end
end
