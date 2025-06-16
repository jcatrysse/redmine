namespace :user do
  desc "Check group memberships for users in 'ldap_sync_users' and update notification preferences"
  task disable_mail_ldap_users: :environment do
    sync_group = Group.find_by_lastname('ldap_sync_users')
    if sync_group.nil?
      puts "Group 'ldap_sync_users' not found."
      next
    end

    User.joins(:groups).where(groups: { id: sync_group.id }).find_each do |user|
      other_groups = user.groups.reject { |g| g.id == sync_group.id }

      if other_groups.any?
        # Gebruiker is ook lid van andere groepen — geen aanpassing
        puts "SKIP: #{user.login} is also in groups: #{other_groups.map(&:lastname).join(', ')}"
      else
        # Gebruiker is alleen in ldap_sync_users => voorkeuren aanpassen
        puts "UPDATE: #{user.login} is only in ldap_sync_users — updating preferences..."

        # Corrigeer notificatie-instellingen
        user.mail_notification = 'only_assigned'
        user.pref[:no_self_notified] = true
        user.pref[:auto_watch_on] = ['']
        user.pref.save
        user.save(validate: false)
      end
    end
  end
end
