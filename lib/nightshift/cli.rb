module Nightshift
  module CLI
    COMMANDS = %w[attach refresh status watch diagnose autofix brief merge].freeze

    module_function

    def run(args)
      cmd = args.shift
      case cmd
      when "status"   then cmd_status(args)
      when "refresh"  then cmd_refresh(args)
      when "merge"    then cmd_merge(args)
      when "brief"    then cmd_brief(args)
      when "diagnose" then cmd_diagnose(args)
      when "autofix"  then cmd_autofix(args)
      when "watch"    then cmd_watch(args)
      when "attach"   then cmd_attach(args)
      else
        usage
      end
    end

    def cmd_status(_args)
      store = Store.new
      puts ""
      store.all_prs.each do |row|
        pr = PR.from_db(row)
        puts "  #{pr.badge}  ##{pr.number}  #{pr.branch}"
      end
      puts ""
    end

    def cmd_refresh(_args)
      prs = GitHub.fetch_prs
      store = Store.new
      renderer = Renderer.new
      reconciler = Reconciler.new(store: store, renderer: renderer)
      reconciler.reconcile(prs)
      puts "Refreshed #{prs.size} PRs"
    end

    def cmd_merge(args)
      pr_number = args.shift or abort("Usage: nightshift merge <pr-number>")
      system("gh", "pr", "merge", pr_number, "--auto", "--squash",
             chdir: ENV.fetch("NIGHTSHIFT_REPO"))
    end

    def cmd_brief(_args)
      store = Store.new
      Brief.generate(store)
    end

    def cmd_diagnose(args)
      pr_number = args.shift or abort("Usage: nightshift diagnose <pr-number>")
      Diagnose.run(pr_number)
    end

    def cmd_autofix(args)
      pr_number = args.shift or abort("Usage: nightshift autofix <pr-number>")
      store = Store.new
      Autofix.run(pr_number, store: store)
    end

    def cmd_watch(_args)
      interval = ENV.fetch("NIGHTSHIFT_WATCH_INTERVAL").to_i
      loop do
        cmd_refresh([])
        sleep interval
      end
    end

    def cmd_attach(_args)
      Attach.run
    end

    def fallback_bash(cmd, args)
      bash_path = File.join(__dir__, "../../bin/nightshift")
      unless File.exist?(bash_path)
        abort "nightshift: '#{cmd}' not yet implemented in Ruby"
      end
      exec(bash_path, cmd, *args)
    end

    def usage
      puts "Usage: nightshift <#{COMMANDS.join('|')}>"
      exit 1
    end
  end
end
