-- spread journal and time-entry dates between issue creation and now (deterministic); idempotent
UPDATE journals j SET created_on = i.created_on + ((j.id % 997) / 997.0) * (TIMESTAMP '2026-10-14 11:00' - i.created_on)
  FROM issues i WHERE j.journalized_type = 'Issue' AND j.journalized_id = i.id AND i.id <> 1;
UPDATE journals SET updated_on = created_on;
UPDATE time_entries SET created_on = spent_on + TIME '10:00', updated_on = spent_on + TIME '10:00';
VACUUM ANALYZE;
-- plugin rows and wiki edits: dates follow their issue / are spread over the past year instead of all "now"
UPDATE checklists c SET created_at = i.created_on, updated_at = i.updated_on FROM issues i WHERE i.id = c.issue_id;
UPDATE taggings t SET created_at = i.created_on FROM issues i WHERE i.id = t.taggable_id AND t.taggable_type = 'Issue';
UPDATE contacts SET created_on = TIMESTAMP '2026-10-14 10:00' - (id % 700) * INTERVAL '1 day', updated_on = TIMESTAMP '2026-10-14 10:00' - (id % 700) * INTERVAL '1 day';
UPDATE helpdesk_tickets h SET ticket_date = i.created_on FROM issues i WHERE i.id = h.issue_id;
UPDATE journal_messages m SET message_date = j.created_on FROM journals j WHERE j.id = m.journal_id;
UPDATE wiki_content_versions SET updated_on = TIMESTAMP '2026-10-14 10:00' - (id % 365) * INTERVAL '1 day';
UPDATE wiki_contents SET updated_on = TIMESTAMP '2026-10-14 10:00' - (id % 365) * INTERVAL '1 day';
VACUUM ANALYZE;
