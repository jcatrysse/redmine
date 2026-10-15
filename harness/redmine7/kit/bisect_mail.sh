#!/bin/bash
cd /home/user/r70h/kit
./05_attrib.sh mailA "redmine_extended_api redmine_issue_field_visibility redmine_people redmine_zenedit" "redmine_stealth"
./05_attrib.sh mailB "redmine_mail_digest redmine_ai_triage redmine_contacts_helpdesk" "redmine_stealth"
./05_attrib.sh mailC "redmine_view_issue_description" "redmine_stealth redmine_wiki_extensions redmine_inline_edit_issues redmine_editauthor"
