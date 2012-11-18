# encoding: utf-8

module Pelusa
  class StdoutReporter < Reporter
    def self.print_banner
      puts "  \e[0;35mϟ\e[0m \e[0;32mPelusa \e[0;35mϟ\e[0m"
      puts "  \e[0;37m----------\e[0m"
    end

    def report
      puts "  \e[0;36m#{@filename}\e[0m"

      @reports.each do |class_report|
        print_report(class_report)
        puts
      end
      puts "\n"
    end

    private

    def print_report(class_report)
      class_name = class_report.class_name

      print "  #{class_report.type} #{class_name}"
      puts class_report.successful? ? success_mark : failure_mark

      if verbose? || !class_report.successful?
        analyses = class_report.analyses
        analyses.each do |analysis|
          print_analysis(analysis)
        end
      end
    end

    def print_analysis(analysis)
      name    = analysis.name
      status  = analysis.status
      message = analysis.message

      print "    \e[0;33m✿ %s \e[0m" % name

      if analysis.successful?
        puts success_mark
        return
      end

      puts failure_mark
      puts "\t" + message
      print "\e[0m"
    end

    # Internal: print a success checkmark.
    def success_mark
      "\e[0;32m✓\e[0m"
    end

    # Internal: print a failure x.
    def failure_mark
      "\e[0;31m✗"
    end

    # Internal: Print verbose information, such as details of passed lints.
    def verbose?
      Pelusa.configuration["global"].fetch("verbose", false)
    end
  end
end
