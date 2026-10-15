# A customer mail to project crm whose subject names a helpdesk-project issue ("[Support #N]"): on 5.1 with
# helpdesk_issue_reply_scope = project it must become a new ticket in crm; on 7.0 the setting no longer exists and
# helpdesk_prefer_target_project decides. Prints where the mail went. Changes data: run last.
ActionMailer::Base.perform_deliveries = false
hd = Project.find_by(identifier: 'helpdesk'); crm = Project.find_by(identifier: 'crm')
target = Issue.where(project_id: hd.id).open.order(:id).first
before = { journals: target.journals.count, crm_issues: crm.issues.count }
s = RedmineHelpdesk.respond_to?(:settings) ? RedmineHelpdesk.settings : Setting.plugin_redmine_contacts_helpdesk
puts "settings: helpdesk_issue_reply_scope=#{s['helpdesk_issue_reply_scope'].inspect} helpdesk_prefer_target_project=#{s['helpdesk_prefer_target_project'].inspect}"
raw = "From: Customer 1 <cust1@client.invalid>\r\nTo: crm@geoxyz.invalid\r\nSubject: Re: [#{target.tracker.name} ##{target.id}] question\r\nMessage-ID: <scope-#{Time.now.to_i}@client.invalid>\r\n" \
      "Date: #{Time.now.rfc2822}\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nAbout the CRM project\r\n"
HelpdeskMailer.receive(raw, issue: { project: 'crm' })
after = { journals: target.reload.journals.count, crm_issues: crm.issues.count }
where = after[:journals] > before[:journals] ? "added to #{hd.identifier} issue ##{target.id} (other project)" : (after[:crm_issues] > before[:crm_issues] ? 'new ticket in crm' : 'nothing created')
puts "mail to crm naming ##{target.id}: #{where}"
