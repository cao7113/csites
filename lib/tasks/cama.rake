desc 'manage cama resources'
namespace :cama do
  desc "Massage 线上数据"
  task massage: :environment do
    puts "==massaging cama users"
    Cama::User.find_each do |u|
      u.password = 'admin123'
      u.save!
      puts "==massage cama user id=#{u.id}: #{u.username}"
    end
  end
end
