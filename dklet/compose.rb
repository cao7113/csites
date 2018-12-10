#!/usr/bin/env rundklet
register_net
register_approot script_path.join('..')
register :appname, approot.basename.to_s
register_app_tag :rails_web
register_build_root approot

add_dsl do
  def web_domain
    ENV['WEB_DOMAIN'] || smart_proxy_domain
  end
end

write_dockerfile <<~Desc
  FROM ruby:2.5-alpine
  LABEL <%=image_labels%>
  ARG TIMEZONE=Asia/Shanghai
  RUN apk add --no-cache tzdata build-base nodejs postgresql-dev imagemagick && \
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

# in docker-compose.yml style
write_specfile <<~Desc
  version: '2'
  services:
    app:
      image: #{docker_image}
      ports:
        - 3000
      <%if in_prod?%>
      restart: always
      <%end%>
      volumes:
        - #{app_volume_for(:public_media)}:/src/public/media
      <%if in_dev? %>
        - .:/src
      <%end%>

      environment:
      - RAILS_ENV=<%=rails_env%>
      <%if in_prod?%>
      - ACTION_MAILER_URL_HOST=<%=web_domain%>
      <%end%>

      <%if in_prod?%>
      - RAILS_SERVE_STATIC_FILES=1
      <%end%>

      env_file:
        - <%=local_env_file %>
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
end

__END__

