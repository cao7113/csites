#!/usr/bin/env rundklet
register_net
register_approot script_path.join('..')
register :appname, approot.basename.to_s
register_app_tag :rails_web
register_build_root approot

add_dsl do
  def ngfile
    script_path.join('web/local-Dockerfile')
  end

  ## use nginx as web server?
  def nginx?
    !!ENV['NGINX']
  end

  def web_domain
    smart_proxy_domain
  end
end

write_dockerfile <<~Desc
  FROM ruby:2.5-alpine
  LABEL <%=image_labels%>
  ARG TIMEZONE=Asia/Shanghai
  RUN apk add --no-cache tzdata build-base nodejs postgresql-dev git && \
      cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
      echo "Timezone set to: $TIMEZONE" && \
      echo "${TIMEZONE}" > /etc/timezone
  WORKDIR /src
  CMD ["thor", ":start"]
  ARG GEM_MIRROR=https://rubygems.org
  RUN echo using gems mirror: $GEM_MIRROR && \
      bundle config mirror.https://rubygems.org $GEM_MIRROR && \
      mkdir -p lib app/apps
  COPY lib/plugin_routes.rb lib/
  COPY app/apps app/apps/
  COPY Gemfile Gemfile.lock ./
  <% if in_dev? %>
  RUN bundle install -j4 --retry 3 --verbose
  <% elsif in_prod? %>
  RUN bundle install --without development test -j4 --retry 3 --verbose
  COPY . .
  <% end %>
Desc
#use https://guides.rubyonrails.org/asset_pipeline.html#local-precompilation
#RAILS_ENV=#{rails_env} SECRET_KEY_BASE=xxx bundle exec rake assets:precompile

if nginx?
  rendering <<~Desc, path: ngfile
    FROM nginx:1.15.7-alpine
    #RUN apk add --no-cache apache2-utils
    ENV RAILS_ROOT /src
    WORKDIR $RAILS_ROOT
    RUN mkdir log
    COPY dklet/web/nginx.conf /tmp/docker.nginx
    RUN envsubst '$RAILS_ROOT' < /tmp/docker.nginx > /etc/nginx/conf.d/default.conf
    EXPOSE 80
    # Use the "exec" form of CMD so Nginx shuts down gracefully on SIGTERM (i.e. `docker stop`)
    CMD [ "nginx", "-g", "daemon off;" ]
    COPY --from=#{docker_image} /src/public public
  Desc
end

# in docker-compose.yml style
write_specfile <<~Desc
  version: '2'
  services:
    app:
      image: #{docker_image}
      ports:
        - 3000
      <%if in_dev? %>
      volumes:
        - .:/src
      <%elsif in_prod?%>
      restart: always
      <%end%>

      environment:
      - RAILS_ENV=<%=rails_env%>
      <%if in_prod?%>
      - ACTION_MAILER_URL_HOST=<%=web_domain%>
      <%end%>

      <%if nginx? %>
      - ASSET_HOST=<%=web_domain%>
      <%else%>
      <%if in_prod?%>
      - RAILS_SERVE_STATIC_FILES=1
      <%end%>
      # web part
      - VIRTUAL_HOST=<%=web_domain%>
      <% if ssl_nginx_proxy? %>
      - LETSENCRYPT_HOST=<%=web_domain%>
      - LETSENCRYPT_EMAIL=<%=dklet_config_for(:letsencrypt_mail)%>
      <%end%>
      <%end%>

      env_file:
        - <%=local_env_file %>
    #job:
      #image: #{docker_image}
      #<%if in_dev? %>
      #volumes:
        #- .:/src
      #<%elsif in_prod?%>
      #restart: always
      #<%end%>
      #command: thor :start job
      #environment:
        #- RAILS_ENV=<%=rails_env%>
        #- APP_SERVICE=sidekiq
      #env_file:
        #- <%=local_env_file %>
    <%if nginx?%>
    web:
      build:
        context: .
        dockerfile: <%=ngfile%>
      ports:
        - 80
      environment:
        - VIRTUAL_HOST=<%=web_domain%>
        <% if ssl_nginx_proxy? %>
        - LETSENCRYPT_HOST=<%=web_domain%>
        - LETSENCRYPT_EMAIL=<%=dklet_config_for(:letsencrypt_mail)%>
        <%end%>
    <%end%>
  networks:
    default:
      external:
        name: #{netname}
Desc

task :main do
  if local_env_file.exist?
    puts "config file: #{local_env_file}"
  else
    abort "No config: #{local_env_file}"
  end

  system <<~Desc
    #{compose_cmd} up -d --build
  Desc
end

before_task :clean do
  system <<~Desc
    #{compose_cmd} down
  Desc
end

custom_commands do
  desc 'config', 'show env config'
  option :backup, type: :boolean, banner: 'backup current config', aliases: ["b"]
  option :link, type: :boolean, banner: 'link config to local', aliases: ["l"]
  def config
    puts "# env config file:"
    puts "# #{local_env_file}"
    puts "#" * 40
    puts local_env_file.read

    if options[:backup]
      path = script_path.join("local/backup/#{env}")
      path.mkpath
      dest = "#{path}/env.local-#{Dklet::Util.human_timestamp}"
      system <<~Desc
        cp #{local_env_file} #{dest} 
      Desc
      puts "==back config to #{dest}"
    end

    if options[:link]
      dest = script_path.join("local/#{env}-env.local")
      dest.parent.mkpath
      system <<~Desc
        ln -s #{local_env_file} #{dest} 
      Desc
      puts "==link config to #{dest}"
    end
  end

  desc 'edit', 'edit env config file'
  def edit
    cmds = <<~Desc
      vi #{local_env_file}
      echo #{local_env_file}
    Desc
    system cmds
  end

  no_commands do
    def local_env_file
      Pathname(ENV['LOCAL_ENV_FILE'] || app_config_for('env.local'))
    end
  end
end

__END__

