# Main user interface
# run: `thor -T` or `thor help :start`
begin
  require 'byebug'
rescue Exception
end

class MainThor < Thor
  namespace 'default'
  class_option :env, banner: 'rails env', aliases: [:e]
  class_option :force, type: :boolean, banner: 'forcely do', aliases: [:f]

  desc 'start [APP_SERVICE]', 'run a service'
  def start(service = nil)
    service ||= ENV['APP_SERVICE'] || 'web'
    puts "==run #{service} in rails env: #{rails_env}"

    cmds = 
      case service
      when 'web', 'server'
        <<~Desc
          bundle exec puma -C config/puma.rb
        Desc
      when 'sidekiq', 'job'
        <<~Desc
          bundle exec sidekiq -e #{rails_env} # --verbose
        Desc
      when 'test'
        <<~Desc
          printenv | sort
        Desc
      else
        abort "Unknown service type: #{service}"
      end

    exec cmds
  end

  desc 'boot', 'bootstraping'
  def boot
    return unless yes?("Has setup env config for #{rails_env}?")
    setup_rails_env
    system <<~Desc
      rake db:create db:migrate
    Desc
  end

  desc 'asset', 'recompile assets'
  option :clear, type: :boolean, banner: 'clobber all', aliases: [:c]
  option :build, type: :boolean, banner: 'precompile', aliases: [:b]
  def asset
    #unless options[:force]
      #return unless yes?("Has setup env config for #{rails_env}?")
    #end
    setup_rails_env
    cmds = []
    cmds << "rake assets:clobber" if options[:clear]
    cmds << "rake assets:precompile" if options[:build]
    cmds << "ls -al public/assets"
    root_run cmds.join("\n")
  end

  desc 'runsh', ''
  def runsh(*args)
    setup_rails_env
    root_run "rails #{args.join(' ')}"
  end
  map "run" => "runsh"

  desc 'docker', 'run docker stack in a mode'
  def docker(mode = 'dev')
    system <<~Desc
      echo ==sync master latest code
      git pull || true
      # 远端有(回退commit)force push时会产生冲突
      git reset --hard origin/master
      git log -3
      gname=$(git rev-parse --abbrev-ref HEAD)
      rev=$(git rev-parse --short=8 HEAD)
      echo ==get repo code $gname: $rev

      echo ==restart service in mode: #{mode}
      dklet/compose.rb -e #{mode}

      echo ==finish released $rev
    Desc
  end

  desc 'sidekiq_auth', 'test sidekiq console auth'
  def sidekiq_auth(auth = nil, url = nil)
    url ||= 'http://localhost:3000/sidekiq/'
    auth ||= 'sidekiq:sidekiq'
    cmds = <<~Desc
      curl --digest -Lv -I --user "#{auth}" "#{url}"
    Desc
    system cmds
  end

  private
  
  def rails_env
    return @_env if @_env
    @_env = setup_rails_env
  end

  def setup_rails_env
    out_env = ENV['RAILS_ENV']
    env = options[:env] || out_env || 'development'
    env = case env
      when /^dev/
        'development'
      when /^p/
        'production'
      end
    ENV['RAILS_ENV'] = env if out_env != env 
    env
  end

  def root_path
    Pathname(__dir__)
  end

  def root_run(str)
    Dir.chdir(root_path) do
      system str
    end
  end
end
