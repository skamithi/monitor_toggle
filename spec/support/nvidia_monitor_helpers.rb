module SpecHelpers

  # return :lcd mode for 1 monitor
  # return :clone mode for 2 monitors
  # return :external mode for 3 monitors
  def display_mode(monitor_count)
    case monitor_count
      when 2
        return :clone
      when 3
        return :external
      end
    return :lcd
  end

  def display_mask(monitor_count)
    case monitor_count
      when 3
      mask = '20001'
      when 2
        mask = '10001'
      else
        mask = '10000'
    end
  end

  def monitor_singular_or_plural(monitor_count)
    return (monitor_count > 1)? "monitors are" : "monitor is"
  end

end
