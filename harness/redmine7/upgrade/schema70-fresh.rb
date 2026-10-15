# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_14_150000, computed_custom_field: 20170205204732, issue_recurring: 8, redmine_agile: 8, redmine_ai_summary: 20260201090300, redmine_ai_triage: 20261014150000, redmine_checklists: 8, redmine_contacts: 36, redmine_contacts_helpdesk: 15, redmine_custom_workflows: 20230413125201, redmine_depending_custom_fields: 1, redmine_issue_templates: 20230330055341, redmine_issue_todo_lists2: 10, redmine_issue_view_columns: 3, redmine_itil_priority: 4, redmine_ldap_sync: 20170524063056, redmine_mail_digest: 12, redmine_people: 21, redmine_project_workflows: 7, redmine_reporter_dashboards: 10, redmine_subtask: 20220623160030, redmine_wiki_extensions: 20251130120000, redmine_zenedit: 2, redmineup_tags: 5, view_customize: 8) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", id: :serial, force: :cascade do |t|
    t.string "street1"
    t.string "street2"
    t.string "city"
    t.string "region"
    t.string "postcode"
    t.string "country_code", limit: 2
    t.text "full_address"
    t.string "address_type", limit: 16
    t.string "addressable_type"
    t.integer "addressable_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["address_type"], name: "index_addresses_on_address_type"
    t.index ["addressable_id", "addressable_type"], name: "index_addresses_on_addressable_id_and_addressable_type"
  end

  create_table "agile_colors", id: :serial, force: :cascade do |t|
    t.string "container_type"
    t.integer "container_id"
    t.string "color"
    t.index ["container_id"], name: "index_agile_colors_on_container_id"
    t.index ["container_type"], name: "index_agile_colors_on_container_type"
  end

  create_table "agile_data", id: :serial, force: :cascade do |t|
    t.integer "issue_id"
    t.integer "position"
    t.integer "story_points"
    t.integer "agile_sprint_id"
    t.index ["issue_id"], name: "index_agile_data_on_issue_id"
    t.index ["position"], name: "index_agile_data_on_position"
  end

  create_table "agile_sprints", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "name", null: false
    t.text "description"
    t.integer "status", default: 0, null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "sharing", default: 0, null: false
  end

  create_table "ai_summary_project_settings", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "subtask_summary_max_depth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "auto_generate"
    t.boolean "auto_requires_existing_summary"
    t.string "api_endpoint"
    t.string "api_key"
    t.string "model"
    t.text "system_prompt"
    t.integer "max_completion_tokens"
    t.boolean "debug_logging"
    t.boolean "include_journal_changes"
    t.text "model_parameters_json"
    t.index ["project_id"], name: "index_ai_summary_project_settings_on_project_id", unique: true
  end

  create_table "ai_triage_alert_damping", force: :cascade do |t|
    t.string "kind", limit: 64, null: false
    t.string "fingerprint", limit: 512, null: false
    t.date "alerted_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_ai_triage_alert_damping_on_kind", unique: true
  end

  create_table "ai_triage_attachment_rules", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "position", default: 0, null: false
    t.string "name", limit: 255, null: false
    t.boolean "enabled", default: true, null: false
    t.text "conditions"
    t.text "selectors"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "disclosure", limit: 16, default: "metadata", null: false
    t.boolean "include_helpdesk_mail", default: false, null: false
    t.index ["project_id", "position"], name: "index_ai_triage_attachment_rules_on_project"
  end

  create_table "ai_triage_availabilities", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.string "status", limit: 32, default: "available", null: false
    t.date "unavailable_from"
    t.date "unavailable_until"
    t.integer "capacity_percent", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_ai_triage_availabilities_on_member", unique: true
  end

  create_table "ai_triage_availability_rules", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.string "effect", limit: 16, default: "blocks", null: false
    t.string "part_of_day", limit: 16, default: "all", null: false
    t.string "kind", limit: 16, null: false
    t.date "starts_on"
    t.date "ends_on"
    t.integer "weekday"
    t.integer "ordinal"
    t.integer "day_of_month"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_ai_triage_availability_rules_on_project_and_user"
  end

  create_table "ai_triage_budget_counters", force: :cascade do |t|
    t.string "scope_type", limit: 32, null: false
    t.integer "scope_id", default: 0, null: false
    t.date "usage_date", null: false
    t.integer "calls", default: 0, null: false
    t.bigint "prompt_tokens", default: 0, null: false
    t.bigint "completion_tokens", default: 0, null: false
    t.decimal "cost_spent", precision: 16, scale: 6, default: "0.0", null: false
    t.integer "unpriced_calls", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "alert_band_cost", default: 0, null: false
    t.integer "alert_band_tokens", default: 0, null: false
    t.integer "unmeasured_token_calls", default: 0, null: false
    t.index ["scope_type", "scope_id", "usage_date"], name: "index_ai_triage_budget_counters_on_scope_and_date", unique: true
    t.index ["usage_date"], name: "index_ai_triage_budget_counters_on_usage_date"
  end

  create_table "ai_triage_executions", force: :cascade do |t|
    t.integer "request_id", null: false
    t.integer "issue_id", null: false
    t.integer "project_id", null: false
    t.integer "policy_id"
    t.text "matching_policy_ids"
    t.integer "prompt_version_id"
    t.integer "provider_profile_id"
    t.string "provider_model", limit: 191
    t.text "catalogue_snapshot"
    t.text "raw_response"
    t.text "decision"
    t.text "scorer_breakdown"
    t.text "confidences"
    t.text "applied_changes"
    t.integer "journal_id"
    t.string "validation_outcome", limit: 64
    t.text "fallback_actions"
    t.string "failure_category", limit: 32
    t.boolean "dry_run", default: false, null: false
    t.integer "latency_ms"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.decimal "cost", precision: 12, scale: 6
    t.string "retention_class", limit: 32, default: "standard", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "envelope_snapshot"
    t.string "skip_reason", limit: 64
    t.datetime "pseudonymised_at"
    t.string "detected_language", limit: 40
    t.index ["issue_id"], name: "index_ai_triage_executions_on_issue_id"
    t.index ["journal_id"], name: "index_ai_triage_executions_on_journal_id"
    t.index ["project_id", "dry_run", "created_at"], name: "index_ai_triage_executions_on_project_dry_run_created"
    t.index ["request_id"], name: "index_ai_triage_executions_on_request_id"
    t.index ["retention_class", "created_at"], name: "index_ai_triage_executions_on_retention_class_created"
  end

  create_table "ai_triage_fallback_chains", force: :cascade do |t|
    t.integer "policy_id", null: false
    t.string "failure_category", limit: 30, null: false
    t.text "actions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id", "failure_category"], name: "index_ai_triage_chains_on_policy_and_category", unique: true
  end

  create_table "ai_triage_heartbeats", force: :cascade do |t|
    t.string "kind", limit: 64, null: false
    t.datetime "beat_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_ai_triage_heartbeats_on_kind", unique: true
  end

  create_table "ai_triage_policies", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "position", default: 1, null: false
    t.string "state", limit: 32, default: "disabled", null: false
    t.string "name", limit: 255, null: false
    t.integer "schema_version", default: 1, null: false
    t.text "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "go_live_confirmation"
    t.index ["project_id", "position"], name: "index_ai_triage_policies_on_project_id_and_position"
    t.index ["project_id", "state"], name: "index_ai_triage_policies_on_project_id_and_state"
  end

  create_table "ai_triage_project_providers", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "provider_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "provider_profile_id"], name: "index_ai_triage_project_providers_unique", unique: true
    t.index ["provider_profile_id"], name: "index_ai_triage_project_providers_on_profile"
  end

  create_table "ai_triage_prompt_templates", force: :cascade do |t|
    t.string "name", limit: 191, null: false
    t.text "text", null: false
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_ai_triage_prompt_templates_on_name", unique: true
  end

  create_table "ai_triage_prompt_versions", force: :cascade do |t|
    t.integer "prompt_id", null: false
    t.integer "project_id", null: false
    t.text "text"
    t.integer "author_id"
    t.string "source", limit: 32, default: "edit", null: false
    t.integer "restored_from_version_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "created_at"], name: "index_ai_triage_prompt_versions_on_project_id_and_created_at"
    t.index ["prompt_id", "created_at"], name: "index_ai_triage_prompt_versions_on_prompt_id_and_created_at"
  end

  create_table "ai_triage_prompts", force: :cascade do |t|
    t.integer "project_id", null: false
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_ai_triage_prompts_on_project_id", unique: true
  end

  create_table "ai_triage_provider_profiles", force: :cascade do |t|
    t.string "name", limit: 191, null: false
    t.string "adapter", limit: 32, default: "mock", null: false
    t.string "endpoint", limit: 255
    t.string "provider_model", limit: 191
    t.integer "schema_version", default: 1, null: false
    t.text "params"
    t.text "credential"
    t.decimal "daily_cost_budget", precision: 12, scale: 6
    t.decimal "prompt_cost_per_1k", precision: 12, scale: 6
    t.decimal "completion_cost_per_1k", precision: 12, scale: 6
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "learned_params"
    t.index ["enabled", "adapter"], name: "index_ai_triage_provider_profiles_on_enabled_adapter"
    t.index ["name"], name: "index_ai_triage_provider_profiles_on_name", unique: true
  end

  create_table "ai_triage_requests", force: :cascade do |t|
    t.integer "issue_id", null: false
    t.integer "project_id", null: false
    t.string "state", limit: 32, default: "waiting", null: false
    t.datetime "stable_since", null: false
    t.string "locked_by", limit: 191
    t.datetime "locked_at"
    t.integer "attempts", default: 0, null: false
    t.string "trigger_fingerprint", limit: 100, null: false
    t.string "source_hint", limit: 64
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "not_before"
    t.index ["issue_id", "trigger_fingerprint"], name: "index_ai_triage_requests_on_issue_and_fingerprint", unique: true
    t.index ["project_id", "state"], name: "index_ai_triage_requests_on_project_id_and_state"
    t.index ["state", "created_at"], name: "index_ai_triage_requests_on_state_and_created_at"
    t.index ["state", "locked_at"], name: "index_ai_triage_requests_on_state_and_locked_at"
    t.index ["state", "not_before"], name: "index_ai_triage_requests_on_state_not_before"
    t.index ["state", "stable_since"], name: "index_ai_triage_requests_on_state_and_stable_since"
  end

  create_table "ai_triage_routing_profiles", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.text "skills"
    t.text "languages"
    t.text "responsibilities"
    t.text "tracker_ids"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_ai_triage_routing_profiles_on_member", unique: true
  end

  create_table "ai_triage_stats_panels", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "owner_login", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_ai_triage_stats_panels_on_project_id", unique: true
  end

  create_table "ai_triage_workload_models", force: :cascade do |t|
    t.integer "project_id", null: false
    t.boolean "enabled", default: false, null: false
    t.string "weighting", default: "count", null: false
    t.integer "target"
    t.decimal "unestimated_weight", precision: 8, scale: 2
    t.text "priority_weights"
    t.text "tracker_ids"
    t.text "excluded_status_ids"
    t.text "purpose"
    t.integer "activated_by_id"
    t.datetime "activated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "discount_done_ratio", default: false, null: false
    t.index ["project_id"], name: "index_ai_triage_workload_models_on_project_id", unique: true
  end

  create_table "attachments", id: :serial, force: :cascade do |t|
    t.integer "container_id"
    t.string "container_type", limit: 30
    t.string "filename", default: "", null: false
    t.string "disk_filename", default: "", null: false
    t.bigint "filesize", default: 0, null: false
    t.string "content_type", default: ""
    t.string "digest", limit: 64, default: "", null: false
    t.integer "downloads", default: 0, null: false
    t.integer "author_id", default: 0, null: false
    t.datetime "created_on", precision: nil
    t.string "description"
    t.string "disk_directory"
    t.index ["author_id"], name: "index_attachments_on_author_id"
    t.index ["container_id", "container_type"], name: "index_attachments_on_container_id_and_container_type"
    t.index ["created_on"], name: "index_attachments_on_created_on"
    t.index ["disk_filename"], name: "index_attachments_on_disk_filename"
  end

  create_table "auth_sources", id: :serial, force: :cascade do |t|
    t.string "type", limit: 30, default: "", null: false
    t.string "name", limit: 60, default: "", null: false
    t.string "host", limit: 60
    t.integer "port"
    t.string "account"
    t.string "account_password", default: ""
    t.string "base_dn", limit: 255
    t.string "attr_login", limit: 30
    t.string "attr_firstname", limit: 30
    t.string "attr_lastname", limit: 30
    t.string "attr_mail", limit: 30
    t.boolean "onthefly_register", default: false, null: false
    t.boolean "tls", default: false, null: false
    t.text "filter"
    t.integer "timeout"
    t.boolean "verify_peer", default: true, null: false
    t.index ["id", "type"], name: "index_auth_sources_on_id_and_type"
  end

  create_table "boards", id: :serial, force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "name", default: "", null: false
    t.string "description"
    t.integer "position"
    t.integer "topics_count", default: 0, null: false
    t.integer "messages_count", default: 0, null: false
    t.integer "last_message_id"
    t.integer "parent_id"
    t.index ["last_message_id"], name: "index_boards_on_last_message_id"
    t.index ["project_id"], name: "boards_project_id"
  end

  create_table "canned_responses", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "content"
    t.integer "project_id"
    t.integer "user_id"
    t.boolean "is_public"
  end

  create_table "changes", id: :serial, force: :cascade do |t|
    t.integer "changeset_id", null: false
    t.string "action", limit: 1, default: "", null: false
    t.text "path", null: false
    t.text "from_path"
    t.string "from_revision"
    t.string "revision"
    t.string "branch"
    t.index ["changeset_id"], name: "changesets_changeset_id"
  end

  create_table "changeset_parents", id: false, force: :cascade do |t|
    t.integer "changeset_id", null: false
    t.integer "parent_id", null: false
    t.index ["changeset_id"], name: "changeset_parents_changeset_ids"
    t.index ["parent_id"], name: "changeset_parents_parent_ids"
  end

  create_table "changesets", id: :serial, force: :cascade do |t|
    t.integer "repository_id", null: false
    t.string "revision", null: false
    t.string "committer"
    t.datetime "committed_on", precision: nil, null: false
    t.text "comments"
    t.date "commit_date"
    t.string "scmid"
    t.integer "user_id"
    t.index ["committed_on"], name: "index_changesets_on_committed_on"
    t.index ["repository_id", "revision"], name: "changesets_repos_rev", unique: true
    t.index ["repository_id", "scmid"], name: "changesets_repos_scmid"
    t.index ["repository_id"], name: "index_changesets_on_repository_id"
    t.index ["user_id"], name: "index_changesets_on_user_id"
  end

  create_table "changesets_issues", id: false, force: :cascade do |t|
    t.integer "changeset_id", null: false
    t.integer "issue_id", null: false
    t.index ["changeset_id", "issue_id"], name: "changesets_issues_ids", unique: true
    t.index ["issue_id"], name: "index_changesets_issues_on_issue_id"
  end

  create_table "checklist_template_categories", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "position", default: 1
  end

  create_table "checklist_templates", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "project_id"
    t.integer "category_id"
    t.integer "user_id"
    t.boolean "is_public"
    t.text "template_items"
    t.boolean "is_default", default: false
    t.integer "tracker_id"
    t.index ["tracker_id"], name: "index_checklist_templates_on_tracker_id"
  end

  create_table "checklists", id: :serial, force: :cascade do |t|
    t.boolean "is_done", default: false
    t.text "subject"
    t.integer "position", default: 1
    t.integer "issue_id", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "is_section", default: false
  end

  create_table "comments", id: :serial, force: :cascade do |t|
    t.string "commented_type", limit: 30, default: "", null: false
    t.integer "commented_id", default: 0, null: false
    t.integer "author_id", default: 0, null: false
    t.text "content"
    t.datetime "created_on", precision: nil, null: false
    t.datetime "updated_on", precision: nil, null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["commented_id", "commented_type"], name: "index_comments_on_commented_id_and_commented_type"
  end

  create_table "contacts", id: :serial, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "company"
    t.string "phone"
    t.string "email"
    t.string "website"
    t.string "skype_name"
    t.date "birthday"
    t.string "avatar"
    t.text "background"
    t.string "job_title"
    t.boolean "is_company", default: false
    t.integer "author_id", default: 0, null: false
    t.integer "assigned_to_id"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.string "cached_tag_list"
    t.integer "visibility", default: 0, null: false
    t.index ["assigned_to_id"], name: "index_contacts_on_assigned_to_id"
    t.index ["author_id"], name: "index_contacts_on_author_id"
    t.index ["company"], name: "index_contacts_on_company"
    t.index ["email"], name: "index_contacts_on_email"
    t.index ["first_name"], name: "index_contacts_on_first_name"
    t.index ["is_company"], name: "index_contacts_on_is_company"
  end

  create_table "contacts_deals", id: false, force: :cascade do |t|
    t.integer "deal_id"
    t.integer "contact_id"
    t.index ["contact_id"], name: "index_contacts_deals_on_contact_id"
    t.index ["deal_id"], name: "index_contacts_deals_on_deal_id"
  end

  create_table "contacts_issues", id: false, force: :cascade do |t|
    t.integer "issue_id", default: 0, null: false
    t.integer "contact_id", default: 0, null: false
    t.index ["contact_id"], name: "index_contacts_issues_on_contact_id"
    t.index ["issue_id"], name: "index_contacts_issues_on_issue_id"
  end

  create_table "contacts_projects", id: false, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.integer "contact_id", default: 0, null: false
    t.index ["contact_id"], name: "index_contacts_projects_on_contact_id"
    t.index ["project_id"], name: "index_contacts_projects_on_project_id"
  end

  create_table "contacts_queries", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "name", default: "", null: false
    t.text "filters"
    t.integer "user_id", default: 0, null: false
    t.boolean "is_public", default: false, null: false
    t.text "column_names"
    t.text "sort_criteria"
    t.string "group_by"
    t.string "type"
    t.index ["project_id"], name: "index_contacts_queries_on_project_id"
    t.index ["user_id"], name: "index_contacts_queries_on_user_id"
  end

  create_table "custom_field_enumerations", id: :serial, force: :cascade do |t|
    t.integer "custom_field_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 1, null: false
  end

  create_table "custom_fields", id: :serial, force: :cascade do |t|
    t.string "type", limit: 30, default: "", null: false
    t.string "name", limit: 30, default: "", null: false
    t.string "field_format", limit: 30, default: "", null: false
    t.text "possible_values"
    t.string "regexp", default: ""
    t.integer "min_length"
    t.integer "max_length"
    t.boolean "is_required", default: false, null: false
    t.boolean "is_for_all", default: false, null: false
    t.boolean "is_filter", default: false, null: false
    t.integer "position"
    t.boolean "searchable", default: false
    t.text "default_value"
    t.boolean "editable", default: true
    t.boolean "visible", default: true, null: false
    t.boolean "multiple", default: false
    t.text "format_store"
    t.text "description"
    t.text "formula"
    t.boolean "is_computed", default: false
    t.index ["id", "type"], name: "index_custom_fields_on_id_and_type"
  end

  create_table "custom_fields_projects", id: false, force: :cascade do |t|
    t.integer "custom_field_id", default: 0, null: false
    t.integer "project_id", default: 0, null: false
    t.index ["custom_field_id", "project_id"], name: "index_custom_fields_projects_on_custom_field_id_and_project_id", unique: true
  end

  create_table "custom_fields_roles", id: false, force: :cascade do |t|
    t.integer "custom_field_id", null: false
    t.integer "role_id", null: false
    t.index ["custom_field_id", "role_id"], name: "custom_fields_roles_ids", unique: true
  end

  create_table "custom_fields_trackers", id: false, force: :cascade do |t|
    t.integer "custom_field_id", default: 0, null: false
    t.integer "tracker_id", default: 0, null: false
    t.index ["custom_field_id", "tracker_id"], name: "index_custom_fields_trackers_on_custom_field_id_and_tracker_id", unique: true
  end

  create_table "custom_values", id: :serial, force: :cascade do |t|
    t.string "customized_type", limit: 30, default: "", null: false
    t.integer "customized_id", default: 0, null: false
    t.integer "custom_field_id", default: 0, null: false
    t.text "value"
    t.index ["custom_field_id"], name: "index_custom_values_on_custom_field_id"
    t.index ["customized_type", "customized_id", "custom_field_id"], name: "custom_values_customized_custom_field"
  end

  create_table "custom_workflows", id: :serial, force: :cascade do |t|
    t.text "before_save"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "name", default: "", null: false
    t.text "description"
    t.string "string", default: "", null: false
    t.integer "position", default: 1
    t.integer "integer", default: 1, null: false
    t.text "after_save"
    t.boolean "is_for_all", default: false, null: false
    t.string "author"
    t.boolean "active", default: true, null: false
    t.string "observable", default: "issue", null: false
    t.text "shared_code"
    t.text "before_add"
    t.text "after_add"
    t.text "before_remove"
    t.text "after_remove"
    t.text "before_destroy"
    t.text "after_destroy"
    t.index ["name"], name: "index_custom_workflows_on_name", unique: true
  end

  create_table "custom_workflows_projects", id: false, force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "custom_workflow_id", null: false
  end

  create_table "dayoffs", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "leave_type_id", null: false
    t.boolean "approved", default: false, null: false
    t.datetime "start_date", precision: nil, null: false
    t.datetime "end_date", precision: nil
    t.float "hours_per_day"
    t.text "notes"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["leave_type_id"], name: "index_dayoffs_on_leave_type_id"
    t.index ["user_id"], name: "index_dayoffs_on_user_id"
  end

  create_table "dcf_config_audit_events", force: :cascade do |t|
    t.integer "project_id"
    t.integer "custom_field_id"
    t.string "custom_field_name", limit: 255
    t.integer "acting_user_id"
    t.string "acting_user_name", limit: 255
    t.string "action", limit: 64, null: false
    t.string "status", limit: 32, default: "success", null: false
    t.text "before_value"
    t.text "after_value"
    t.string "changes_summary", limit: 1000
    t.integer "affected_projects_count"
    t.integer "affected_values_count"
    t.text "affected_child_field_ids"
    t.string "ip_address", limit: 45
    t.string "user_agent", limit: 512
    t.string "request_id", limit: 64
    t.text "error_message"
    t.datetime "created_at", precision: nil, null: false
    t.index ["created_at"], name: "index_dcf_audit_on_created"
    t.index ["custom_field_id", "created_at"], name: "index_dcf_audit_on_cf_created"
    t.index ["project_id", "created_at"], name: "index_dcf_audit_on_project_created"
  end

  create_table "deal_categories", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "project_id"
    t.index ["project_id"], name: "index_deal_categories_on_project_id"
  end

  create_table "deal_processes", id: :serial, force: :cascade do |t|
    t.integer "deal_id", null: false
    t.integer "author_id", null: false
    t.integer "old_value"
    t.integer "value", null: false
    t.datetime "created_at", precision: nil
    t.index ["author_id"], name: "index_deal_processes_on_author_id"
    t.index ["deal_id"], name: "index_deal_processes_on_deal_id"
  end

  create_table "deal_statuses", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "position"
    t.boolean "is_default", default: false, null: false
    t.integer "color", default: 11184810, null: false
    t.integer "status_type", default: 0, null: false
  end

  create_table "deal_statuses_projects", id: false, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.integer "deal_status_id", default: 0, null: false
    t.index ["project_id", "deal_status_id"], name: "index_deal_statuses_projects_on_project_id_and_deal_status_id"
  end

  create_table "deals", id: :serial, force: :cascade do |t|
    t.string "name"
    t.text "background"
    t.string "currency"
    t.integer "duration", default: 1
    t.decimal "price", precision: 20, scale: 2
    t.integer "price_type"
    t.integer "project_id"
    t.integer "author_id"
    t.integer "assigned_to_id"
    t.integer "status_id"
    t.integer "contact_id"
    t.integer "category_id"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.datetime "due_date", precision: nil
    t.integer "probability"
    t.index ["author_id"], name: "index_deals_on_author_id"
    t.index ["category_id"], name: "index_deals_on_category_id"
    t.index ["contact_id"], name: "index_deals_on_contact_id"
    t.index ["project_id"], name: "index_deals_on_project_id"
    t.index ["status_id"], name: "index_deals_on_status_id"
  end

  create_table "deals_issues", id: :serial, force: :cascade do |t|
    t.integer "issue_id", default: 0, null: false
    t.integer "deal_id", default: 0, null: false
    t.index ["deal_id"], name: "index_deals_issues_on_deal_id"
    t.index ["issue_id"], name: "index_deals_issues_on_issue_id"
  end

  create_table "departments", id: :serial, force: :cascade do |t|
    t.integer "parent_id"
    t.integer "lft"
    t.integer "rgt"
    t.string "name"
    t.text "background"
    t.integer "head_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["head_id"], name: "index_departments_on_head_id"
    t.index ["parent_id", "lft", "rgt"], name: "index_departments_on_parent_id_and_lft_and_rgt"
  end

  create_table "documents", id: :serial, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.integer "category_id", default: 0, null: false
    t.string "title", default: "", null: false
    t.text "description"
    t.datetime "created_on", precision: nil
    t.index ["category_id"], name: "index_documents_on_category_id"
    t.index ["created_on"], name: "index_documents_on_created_on"
    t.index ["project_id"], name: "documents_project_id"
  end

  create_table "drafts", force: :cascade do |t|
    t.string "target_type", limit: 150, null: false
    t.bigint "user_id"
    t.string "parent_type"
    t.bigint "parent_id"
    t.binary "data", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_type", "parent_id"], name: "index_drafts_on_parent"
    t.index ["user_id", "target_type"], name: "index_drafts_on_user_id_and_target_type"
    t.index ["user_id"], name: "index_drafts_on_user_id"
  end

  create_table "email_addresses", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "address", null: false
    t.boolean "is_default", default: false, null: false
    t.boolean "notify", default: true, null: false
    t.datetime "created_on", precision: nil, null: false
    t.datetime "updated_on", precision: nil, null: false
    t.index ["user_id"], name: "index_email_addresses_on_user_id"
  end

  create_table "enabled_modules", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "name", null: false
    t.index ["project_id"], name: "enabled_modules_project_id"
  end

  create_table "enumerations", id: :serial, force: :cascade do |t|
    t.string "name", limit: 30, default: "", null: false
    t.integer "position"
    t.boolean "is_default", default: false, null: false
    t.string "type"
    t.boolean "active", default: true, null: false
    t.integer "project_id"
    t.integer "parent_id"
    t.string "position_name", limit: 30
    t.index ["id", "type"], name: "index_enumerations_on_id_and_type"
    t.index ["project_id"], name: "index_enumerations_on_project_id"
  end

  create_table "global_issue_templates", id: :serial, force: :cascade do |t|
    t.string "title"
    t.string "issue_title"
    t.integer "tracker_id"
    t.integer "author_id"
    t.string "note"
    t.text "description"
    t.boolean "enabled", default: false, null: false
    t.integer "position"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.text "checklist_json"
    t.boolean "is_default", default: false, null: false
    t.text "related_link"
    t.text "link_title"
    t.text "builtin_fields_json"
    t.index ["author_id"], name: "index_global_issue_templates_on_author_id"
    t.index ["tracker_id"], name: "index_global_issue_templates_on_tracker_id"
  end

  create_table "global_issue_templates_projects", id: false, force: :cascade do |t|
    t.integer "project_id"
    t.integer "global_issue_template_id"
    t.index ["project_id", "global_issue_template_id"], name: "projects_global_issue_templates", unique: true
  end

  create_table "global_note_templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "memo"
    t.integer "tracker_id"
    t.integer "author_id"
    t.boolean "enabled"
    t.integer "position"
    t.integer "visibility", default: 2
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["author_id"], name: "index_global_note_templates_on_author_id"
    t.index ["enabled"], name: "index_global_note_templates_on_enabled"
    t.index ["tracker_id"], name: "index_global_note_templates_on_tracker_id"
  end

  create_table "global_note_templates_projects", id: false, force: :cascade do |t|
    t.bigint "global_note_template_id", null: false
    t.bigint "project_id", null: false
  end

  create_table "global_note_visible_roles", force: :cascade do |t|
    t.integer "global_note_template_id"
    t.integer "role_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["global_note_template_id"], name: "index_global_note_visible_roles_on_global_note_template_id"
    t.index ["role_id"], name: "index_global_note_visible_roles_on_role_id"
  end

  create_table "groups_users", id: false, force: :cascade do |t|
    t.integer "group_id", null: false
    t.integer "user_id", null: false
    t.index ["group_id", "user_id"], name: "groups_users_ids", unique: true
  end

  create_table "helpdesk_mail_rules", id: :serial, force: :cascade do |t|
    t.integer "mail_type"
    t.text "conditions"
    t.text "actions"
    t.integer "user_id", null: false
    t.integer "position", default: 0
  end

  create_table "helpdesk_tickets", id: :serial, force: :cascade do |t|
    t.integer "contact_id"
    t.integer "issue_id"
    t.integer "source", default: 0, null: false
    t.string "from_address"
    t.text "to_address"
    t.datetime "ticket_date", precision: nil
    t.text "cc_address"
    t.string "message_id"
    t.boolean "is_incoming", default: true
    t.integer "reaction_time"
    t.integer "first_response_time"
    t.integer "resolve_time"
    t.datetime "last_agent_response_at", precision: nil
    t.datetime "last_contact_response_at", precision: nil
    t.integer "vote"
    t.string "vote_comment"
    t.string "view_id"
    t.datetime "viewed_on", precision: nil
    t.boolean "reopen_locked", default: false, null: false
    t.index ["issue_id", "contact_id"], name: "index_helpdesk_tickets_on_issue_id_and_contact_id"
    t.index ["message_id"], name: "index_helpdesk_tickets_on_message_id"
    t.index ["ticket_date"], name: "index_helpdesk_tickets_on_ticket_date"
  end

  create_table "import_items", id: :serial, force: :cascade do |t|
    t.integer "import_id", null: false
    t.integer "position", null: false
    t.integer "obj_id"
    t.text "message"
    t.string "unique_id"
    t.index ["import_id", "unique_id"], name: "index_import_items_on_import_id_and_unique_id"
  end

  create_table "imports", id: :serial, force: :cascade do |t|
    t.string "type"
    t.integer "user_id", null: false
    t.string "filename"
    t.text "settings"
    t.integer "total_items"
    t.boolean "finished", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "issue_categories", id: :serial, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.string "name", limit: 60, default: "", null: false
    t.integer "assigned_to_id"
    t.index ["assigned_to_id"], name: "index_issue_categories_on_assigned_to_id"
    t.index ["project_id"], name: "issue_categories_project_id"
  end

  create_table "issue_digest_deliveries", force: :cascade do |t|
    t.bigint "issue_digest_run_id", null: false
    t.integer "user_id"
    t.string "email", limit: 255, null: false
    t.string "status", limit: 20, default: "sent", null: false
    t.integer "issues_count", default: 0, null: false
    t.datetime "sent_at", precision: nil
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_digest_run_id"], name: "idx_issue_digest_deliveries_run_id"
    t.index ["status"], name: "index_issue_digest_deliveries_on_status"
    t.index ["user_id"], name: "index_issue_digest_deliveries_on_user_id"
  end

  create_table "issue_digest_rules", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "name", limit: 255, null: false
    t.boolean "active", default: true, null: false
    t.string "schedule_type", limit: 30, null: false
    t.text "schedule_config", null: false
    t.date "start_on"
    t.date "end_on"
    t.time "send_time"
    t.string "timezone", limit: 64, default: "UTC", null: false
    t.integer "grace_window_hours", default: 24, null: false
    t.string "last_schedule_key", limit: 100
    t.boolean "business_days_only", default: false, null: false
    t.string "non_business_day_behavior", limit: 20, default: "skip", null: false
    t.integer "query_id"
    t.boolean "include_subprojects", default: false, null: false
    t.boolean "include_open", default: true, null: false
    t.boolean "include_closed", default: false, null: false
    t.boolean "include_overdue", default: false, null: false
    t.boolean "include_due_soon", default: false, null: false
    t.integer "due_soon_days", default: 7, null: false
    t.boolean "include_recently_updated", default: false, null: false
    t.integer "recently_updated_days", default: 7, null: false
    t.boolean "include_recently_created", default: false, null: false
    t.integer "recently_created_days", default: 7, null: false
    t.boolean "filter_assigned_to_recipient", default: false, null: false
    t.boolean "filter_watched_by_recipient", default: false, null: false
    t.boolean "filter_authored_by_recipient", default: false, null: false
    t.text "recipient_modes", null: false
    t.string "group_by", limit: 20, default: "none", null: false
    t.boolean "send_empty", default: false, null: false
    t.string "email_subject", limit: 255
    t.text "email_intro"
    t.datetime "last_run_at", precision: nil
    t.datetime "last_success_at", precision: nil
    t.integer "created_by_id", null: false
    t.integer "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "overdue_min_days"
    t.boolean "since_last_run_created", default: false, null: false
    t.boolean "since_last_run_updated", default: false, null: false
    t.boolean "include_starting_soon", default: false, null: false
    t.integer "starting_soon_days", default: 7, null: false
    t.boolean "filter_unassigned", default: false, null: false
    t.index ["active", "project_id", "last_run_at"], name: "idx_issue_digest_rules_due"
    t.index ["active"], name: "index_issue_digest_rules_on_active"
    t.index ["created_by_id"], name: "index_issue_digest_rules_on_created_by_id"
    t.index ["last_schedule_key"], name: "index_issue_digest_rules_on_last_schedule_key"
    t.index ["project_id"], name: "index_issue_digest_rules_on_project_id"
    t.index ["query_id"], name: "index_issue_digest_rules_on_query_id"
    t.index ["updated_by_id"], name: "index_issue_digest_rules_on_updated_by_id"
  end

  create_table "issue_digest_runs", force: :cascade do |t|
    t.bigint "issue_digest_rule_id", null: false
    t.datetime "started_at", precision: nil, null: false
    t.datetime "finished_at", precision: nil
    t.string "status", limit: 20, default: "running", null: false
    t.string "trigger", limit: 20, default: "scheduled", null: false
    t.string "schedule_key", limit: 100
    t.integer "recipients_count", default: 0, null: false
    t.integer "emails_sent_count", default: 0, null: false
    t.integer "emails_failed_count", default: 0, null: false
    t.integer "issues_count", default: 0, null: false
    t.text "warning_message"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_digest_rule_id", "schedule_key"], name: "idx_issue_digest_runs_rule_schedule_key", unique: true
    t.index ["issue_digest_rule_id", "started_at"], name: "idx_issue_digest_runs_rule_started"
    t.index ["issue_digest_rule_id"], name: "idx_issue_digest_runs_rule_id"
    t.index ["started_at"], name: "index_issue_digest_runs_on_started_at"
    t.index ["status"], name: "index_issue_digest_runs_on_status"
  end

  create_table "issue_recurrences", id: :serial, force: :cascade do |t|
    t.integer "issue_id"
    t.integer "last_issue_id"
    t.integer "count"
    t.integer "creation_mode"
    t.integer "anchor_mode"
    t.integer "mode"
    t.integer "multiplier"
    t.integer "delay_mode"
    t.integer "delay_multiplier"
    t.boolean "include_subtasks"
    t.date "date_limit"
    t.integer "count_limit"
    t.boolean "anchor_to_start"
    t.date "anchor_date"
    t.index ["issue_id"], name: "index_issue_recurrences_on_issue_id"
    t.index ["last_issue_id"], name: "index_issue_recurrences_on_last_issue_id"
  end

  create_table "issue_relations", id: :serial, force: :cascade do |t|
    t.integer "issue_from_id", null: false
    t.integer "issue_to_id", null: false
    t.string "relation_type", default: "", null: false
    t.integer "delay"
    t.index ["issue_from_id", "issue_to_id", "relation_type"], name: "index_issue_relations_on_from_to_type", unique: true
    t.index ["issue_from_id"], name: "index_issue_relations_on_issue_from_id"
    t.index ["issue_to_id"], name: "index_issue_relations_on_issue_to_id"
  end

  create_table "issue_statuses", id: :serial, force: :cascade do |t|
    t.string "name", limit: 30, default: "", null: false
    t.boolean "is_closed", default: false, null: false
    t.integer "position"
    t.integer "default_done_ratio"
    t.string "description"
    t.index ["is_closed"], name: "index_issue_statuses_on_is_closed"
    t.index ["position"], name: "index_issue_statuses_on_position"
  end

  create_table "issue_summaries", force: :cascade do |t|
    t.integer "issue_id"
    t.text "summary"
    t.integer "created_by"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "updated_by"
    t.string "status", default: "stale"
    t.text "error_message"
    t.index ["issue_id"], name: "index_issue_summaries_on_issue_id", unique: true
  end

  create_table "issue_template_settings", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.text "help_message"
    t.boolean "enabled"
    t.boolean "should_replaced", default: false
    t.boolean "inherit_templates", default: false, null: false
  end

  create_table "issue_templates", id: :serial, force: :cascade do |t|
    t.string "title", null: false
    t.integer "project_id"
    t.integer "tracker_id", null: false
    t.integer "author_id", null: false
    t.string "note"
    t.text "description"
    t.boolean "enabled", default: false, null: false
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.string "issue_title"
    t.integer "position", default: 1
    t.boolean "is_default", default: false
    t.boolean "enabled_sharing", default: false
    t.text "checklist_json"
    t.text "related_link"
    t.text "link_title"
    t.text "builtin_fields_json"
    t.index ["author_id"], name: "index_issue_templates_on_author_id"
    t.index ["project_id"], name: "index_issue_templates_on_project_id"
    t.index ["tracker_id"], name: "index_issue_templates_on_tracker_id"
  end

  create_table "issue_todo_list_items", id: :serial, force: :cascade do |t|
    t.integer "issue_todo_list_id"
    t.integer "issue_id"
    t.integer "position"
    t.text "comment"
    t.text "data"
    t.index ["issue_id"], name: "index_issue_todo_list_items_on_issue_id"
    t.index ["issue_todo_list_id", "position"], name: "index_issue_todo_list_items_on_list_and_position"
  end

  create_table "issue_todo_lists", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.integer "created_by_id"
    t.datetime "last_updated", precision: nil
    t.integer "last_updated_by_id"
    t.boolean "remove_closed_issues", default: false, null: false
    t.integer "project_id"
    t.text "included_columns"
    t.text "included_fields"
    t.index ["project_id"], name: "index_issue_todo_lists_on_project_id"
  end

  create_table "issue_view_columns", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "ident"
    t.integer "order"
  end

  create_table "issues", id: :serial, force: :cascade do |t|
    t.integer "tracker_id", null: false
    t.integer "project_id", null: false
    t.string "subject", default: "", null: false
    t.text "description"
    t.date "due_date"
    t.integer "category_id"
    t.integer "status_id", null: false
    t.integer "assigned_to_id"
    t.integer "priority_id", null: false
    t.integer "fixed_version_id"
    t.integer "author_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.date "start_date"
    t.integer "done_ratio", default: 0, null: false
    t.float "estimated_hours"
    t.integer "parent_id"
    t.integer "root_id"
    t.integer "lft"
    t.integer "rgt"
    t.boolean "is_private", default: false, null: false
    t.datetime "closed_on", precision: nil
    t.integer "impact_id"
    t.integer "urgency_id"
    t.boolean "itil_priority_linked", default: true, null: false
    t.text "cached_tag_names"
    t.integer "recurrence_of_id"
    t.index ["assigned_to_id"], name: "index_issues_on_assigned_to_id"
    t.index ["author_id"], name: "index_issues_on_author_id"
    t.index ["category_id"], name: "index_issues_on_category_id"
    t.index ["created_on"], name: "index_issues_on_created_on"
    t.index ["fixed_version_id"], name: "index_issues_on_fixed_version_id"
    t.index ["impact_id", "urgency_id"], name: "index_issues_on_impact_id_and_urgency_id"
    t.index ["impact_id"], name: "index_issues_on_impact_id"
    t.index ["parent_id"], name: "index_issues_on_parent_id"
    t.index ["priority_id"], name: "index_issues_on_priority_id"
    t.index ["project_id"], name: "issues_project_id"
    t.index ["recurrence_of_id"], name: "index_issues_on_recurrence_of_id"
    t.index ["root_id", "lft", "rgt"], name: "index_issues_on_root_id_and_lft_and_rgt"
    t.index ["status_id"], name: "index_issues_on_status_id"
    t.index ["tracker_id"], name: "index_issues_on_tracker_id"
    t.index ["urgency_id"], name: "index_issues_on_urgency_id"
  end

  create_table "journal_details", id: :serial, force: :cascade do |t|
    t.integer "journal_id", default: 0, null: false
    t.string "property", limit: 30, default: "", null: false
    t.string "prop_key", limit: 30, default: "", null: false
    t.text "old_value"
    t.text "value"
    t.index ["journal_id"], name: "journal_details_journal_id"
  end

  create_table "journal_messages", id: :serial, force: :cascade do |t|
    t.integer "contact_id"
    t.integer "journal_id"
    t.boolean "is_incoming"
    t.integer "source", default: 0, null: false
    t.string "from_address"
    t.text "to_address"
    t.text "bcc_address"
    t.text "cc_address"
    t.datetime "message_date", precision: nil
    t.string "message_id"
    t.string "view_id"
    t.datetime "viewed_on", precision: nil
    t.index ["journal_id", "contact_id"], name: "index_journal_messages_on_journal_id_and_contact_id"
    t.index ["message_date"], name: "index_journal_messages_on_message_date"
    t.index ["message_id"], name: "index_journal_messages_on_message_id"
  end

  create_table "journals", id: :serial, force: :cascade do |t|
    t.integer "journalized_id", default: 0, null: false
    t.string "journalized_type", limit: 30, default: "", null: false
    t.integer "user_id", default: 0, null: false
    t.text "notes"
    t.datetime "created_on", precision: nil, null: false
    t.boolean "private_notes", default: false, null: false
    t.datetime "updated_on", precision: nil
    t.integer "updated_by_id"
    t.index ["created_on"], name: "index_journals_on_created_on"
    t.index ["journalized_id", "journalized_type"], name: "journals_journalized_id"
    t.index ["journalized_id"], name: "index_journals_on_journalized_id"
    t.index ["user_id"], name: "index_journals_on_user_id"
  end

  create_table "leave_types", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.boolean "paid"
    t.boolean "approvable"
  end

  create_table "member_roles", id: :serial, force: :cascade do |t|
    t.integer "member_id", null: false
    t.integer "role_id", null: false
    t.integer "inherited_from"
    t.index ["inherited_from"], name: "index_member_roles_on_inherited_from"
    t.index ["member_id"], name: "index_member_roles_on_member_id"
    t.index ["role_id"], name: "index_member_roles_on_role_id"
  end

  create_table "members", id: :serial, force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.integer "project_id", default: 0, null: false
    t.datetime "created_on", precision: nil
    t.boolean "mail_notification", default: false, null: false
    t.index ["project_id"], name: "index_members_on_project_id"
    t.index ["user_id", "project_id"], name: "index_members_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "messages", id: :serial, force: :cascade do |t|
    t.integer "board_id", null: false
    t.integer "parent_id"
    t.string "subject", default: "", null: false
    t.text "content"
    t.integer "author_id"
    t.integer "replies_count", default: 0, null: false
    t.integer "last_reply_id"
    t.datetime "created_on", precision: nil, null: false
    t.datetime "updated_on", precision: nil, null: false
    t.boolean "locked", default: false
    t.integer "sticky", default: 0
    t.index ["author_id"], name: "index_messages_on_author_id"
    t.index ["board_id"], name: "messages_board_id"
    t.index ["created_on"], name: "index_messages_on_created_on"
    t.index ["last_reply_id"], name: "index_messages_on_last_reply_id"
    t.index ["parent_id"], name: "messages_parent_id"
  end

  create_table "news", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "title", limit: 60, default: "", null: false
    t.string "summary", limit: 255, default: ""
    t.text "description"
    t.integer "author_id", default: 0, null: false
    t.datetime "created_on", precision: nil
    t.integer "comments_count", default: 0, null: false
    t.index ["author_id"], name: "index_news_on_author_id"
    t.index ["created_on"], name: "index_news_on_created_on"
    t.index ["project_id"], name: "news_project_id"
  end

  create_table "note_templates", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "memo"
    t.integer "project_id"
    t.integer "tracker_id"
    t.integer "author_id"
    t.boolean "enabled"
    t.integer "position"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "visibility", default: 2
    t.index ["author_id"], name: "index_note_templates_on_author_id"
    t.index ["enabled"], name: "index_note_templates_on_enabled"
    t.index ["project_id"], name: "index_note_templates_on_project_id"
    t.index ["tracker_id"], name: "index_note_templates_on_tracker_id"
  end

  create_table "note_visible_roles", force: :cascade do |t|
    t.integer "note_template_id"
    t.integer "role_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["note_template_id"], name: "index_note_visible_roles_on_note_template_id"
    t.index ["role_id"], name: "index_note_visible_roles_on_role_id"
  end

  create_table "notes", id: :serial, force: :cascade do |t|
    t.string "subject"
    t.text "content"
    t.integer "source_id"
    t.string "source_type"
    t.integer "author_id"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.integer "type_id"
    t.index ["author_id"], name: "index_notes_on_author_id"
    t.index ["source_id", "source_type"], name: "index_notes_on_source_id_and_source_type"
    t.index ["type_id"], name: "index_notes_on_type_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.text "scopes"
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer "resource_owner_id"
    t.bigint "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.text "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.text "scopes", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "people_announcements", id: :serial, force: :cascade do |t|
    t.text "description"
    t.date "start_date"
    t.date "end_date"
    t.string "frequency"
    t.string "kind"
    t.boolean "active", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "recipient_id"
    t.string "recipient_type"
    t.index ["recipient_id"], name: "index_people_announcements_on_recipient_id"
  end

  create_table "people_holidays", id: :serial, force: :cascade do |t|
    t.string "name"
    t.date "start_date"
    t.date "end_date"
    t.text "description"
    t.boolean "is_workday"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
  end

  create_table "people_information", primary_key: "user_id", id: :serial, force: :cascade do |t|
    t.string "phone"
    t.string "address"
    t.string "skype"
    t.date "birthday"
    t.string "job_title"
    t.string "company"
    t.string "middlename"
    t.integer "gender", limit: 2
    t.string "twitter"
    t.string "facebook"
    t.string "linkedin"
    t.text "background"
    t.date "appearance_date"
    t.integer "department_id"
    t.boolean "is_system", default: false
    t.integer "manager_id"
    t.float "workday_length"
    t.index ["workday_length"], name: "index_people_information_on_workday_length"
  end

  create_table "people_work_experiences", id: :serial, force: :cascade do |t|
    t.string "previous_company_name"
    t.string "job_title"
    t.datetime "from_date", precision: nil
    t.datetime "to_date", precision: nil
    t.text "description"
    t.integer "user_id"
    t.index ["user_id"], name: "index_people_work_experiences_on_user_id"
  end

  create_table "project_workflow_scopes", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "tracker_id", null: false
    t.integer "role_id", null: false
    t.string "rule_type", limit: 20, null: false
    t.integer "created_by_id"
    t.integer "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "rule_type"], name: "index_project_workflow_scopes_on_project_and_rule_type"
    t.index ["project_id", "tracker_id", "role_id", "rule_type"], name: "index_project_workflow_scopes_unique", unique: true
    t.index ["tracker_id", "role_id", "rule_type"], name: "index_project_workflow_scopes_on_tracker_role_rule_type"
  end

  create_table "project_workflow_write_locks", force: :cascade do |t|
    t.string "rule_type", limit: 20, null: false
    t.integer "tracker_id", null: false
    t.integer "role_id", null: false
    t.index ["rule_type", "tracker_id", "role_id"], name: "index_project_workflow_write_locks_unique", unique: true
  end

  create_table "projects", id: :serial, force: :cascade do |t|
    t.string "name", default: "", null: false
    t.text "description"
    t.string "homepage", default: ""
    t.boolean "is_public", default: true, null: false
    t.integer "parent_id"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.string "identifier"
    t.integer "status", default: 1, null: false
    t.integer "lft"
    t.integer "rgt"
    t.boolean "inherit_members", default: false, null: false
    t.integer "default_version_id"
    t.integer "default_assigned_to_id"
    t.integer "default_issue_query_id"
    t.index ["identifier"], name: "index_projects_on_identifier", unique: true
    t.index ["lft"], name: "index_projects_on_lft"
    t.index ["rgt"], name: "index_projects_on_rgt"
  end

  create_table "projects_trackers", id: false, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.integer "tracker_id", default: 0, null: false
    t.index ["project_id", "tracker_id"], name: "projects_trackers_unique", unique: true
    t.index ["project_id"], name: "projects_trackers_project_id"
  end

  create_table "projects_webhooks", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "webhook_id", null: false
    t.index ["project_id"], name: "index_projects_webhooks_on_project_id"
    t.index ["webhook_id"], name: "index_projects_webhooks_on_webhook_id"
  end

  create_table "queries", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "name", default: "", null: false
    t.text "filters"
    t.integer "user_id", default: 0, null: false
    t.text "column_names"
    t.text "sort_criteria"
    t.string "group_by"
    t.string "type"
    t.integer "visibility", default: 0
    t.text "options"
    t.string "description"
    t.index ["project_id"], name: "index_queries_on_project_id"
    t.index ["user_id"], name: "index_queries_on_user_id"
  end

  create_table "queries_roles", id: false, force: :cascade do |t|
    t.integer "query_id", null: false
    t.integer "role_id", null: false
    t.index ["query_id", "role_id"], name: "queries_roles_ids", unique: true
  end

  create_table "reactions", force: :cascade do |t|
    t.string "reactable_type", null: false
    t.bigint "reactable_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reactable_type", "reactable_id", "id"], name: "index_reactions_on_reactable_type_and_reactable_id_and_id"
    t.index ["reactable_type", "reactable_id", "user_id"], name: "index_reactions_on_reactable_type_and_reactable_id_and_user_id", unique: true
    t.index ["reactable_type", "reactable_id"], name: "index_reactions_on_reactable"
    t.index ["user_id"], name: "index_reactions_on_user_id"
  end

  create_table "reporter_dashboards_documents", force: :cascade do |t|
    t.integer "template_id"
    t.integer "project_id"
    t.integer "schedule_run_id"
    t.integer "created_by_id"
    t.integer "rendered_as_user_id"
    t.string "correlation_id"
    t.string "engine"
    t.string "engine_version"
    t.integer "render_duration_ms"
    t.string "content_type"
    t.bigint "byte_size"
    t.integer "page_count"
    t.string "digest"
    t.integer "attachment_id"
    t.datetime "expires_at", precision: nil, null: false
    t.datetime "purged_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_rd_documents_on_correlation_id"
    t.index ["expires_at"], name: "index_rd_documents_on_expires_at"
    t.index ["schedule_run_id"], name: "index_rd_documents_on_schedule_run_id"
    t.index ["template_id"], name: "index_rd_documents_on_template_id"
  end

  create_table "reporter_dashboards_mail_send_recipients", force: :cascade do |t|
    t.integer "mail_send_id", null: false
    t.integer "user_id"
    t.string "address"
    t.datetime "created_at", precision: nil, null: false
    t.index ["mail_send_id"], name: "index_rd_mail_recipients_on_send_id"
    t.index ["user_id"], name: "index_rd_mail_recipients_on_user_id"
  end

  create_table "reporter_dashboards_mail_sends", force: :cascade do |t|
    t.integer "author_id", null: false
    t.integer "project_id", null: false
    t.integer "template_id"
    t.string "template_name"
    t.string "source"
    t.text "issue_ids"
    t.integer "query_id"
    t.string "query_type"
    t.string "status", null: false
    t.text "error"
    t.string "correlation_id"
    t.integer "recipients_count"
    t.integer "external_count"
    t.integer "document_count"
    t.integer "bytes_total"
    t.integer "duration_ms"
    t.datetime "finished_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.index ["author_id", "created_at"], name: "index_rd_mail_sends_on_author_and_created"
    t.index ["project_id"], name: "index_rd_mail_sends_on_project_id"
    t.index ["template_id"], name: "index_rd_mail_sends_on_template_id"
  end

  create_table "reporter_dashboards_schedule_recipients", force: :cascade do |t|
    t.integer "schedule_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["schedule_id", "user_id"], name: "index_rd_recipients_ids", unique: true
    t.index ["user_id"], name: "index_rd_recipients_on_user_id"
  end

  create_table "reporter_dashboards_schedule_runs", force: :cascade do |t|
    t.integer "schedule_id", null: false
    t.date "occurrence_date", null: false
    t.datetime "started_at", precision: nil
    t.datetime "finished_at", precision: nil
    t.string "status"
    t.text "error"
    t.integer "duration_ms"
    t.integer "recipients_count"
    t.integer "document_count"
    t.bigint "bytes_total"
    t.string "correlation_id"
    t.index ["correlation_id"], name: "index_rd_runs_on_correlation_id"
    t.index ["schedule_id", "occurrence_date"], name: "index_rd_runs_on_schedule_and_occurrence", unique: true
  end

  create_table "reporter_dashboards_schedules", force: :cascade do |t|
    t.integer "project_id"
    t.integer "template_id", null: false
    t.integer "author_id", null: false
    t.integer "query_id"
    t.string "query_type"
    t.string "repeat"
    t.date "start_date"
    t.date "end_date"
    t.string "email_subject"
    t.text "email_template"
    t.string "render_as"
    t.integer "render_as_user_id"
    t.string "timezone"
    t.boolean "enabled", default: true, null: false
    t.date "last_run_on"
    t.datetime "last_attempted_at", precision: nil
    t.string "last_status"
    t.text "last_error"
    t.integer "last_duration_ms"
    t.integer "consecutive_failures", default: 0, null: false
    t.date "next_run_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled", "next_run_on"], name: "index_rd_schedules_on_enabled_and_next_run"
    t.index ["project_id"], name: "index_rd_schedules_on_project_id"
    t.index ["template_id"], name: "index_rd_schedules_on_template_id"
  end

  create_table "reporter_dashboards_share_link_accesses", force: :cascade do |t|
    t.integer "share_link_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "outcome", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["share_link_id", "created_at"], name: "index_rd_share_accesses_on_link_and_created"
  end

  create_table "reporter_dashboards_share_links", force: :cascade do |t|
    t.integer "template_id", null: false
    t.integer "project_id"
    t.string "token_digest", null: false
    t.string "scope_kind", null: false
    t.text "scope_payload"
    t.integer "rendered_document_id"
    t.integer "render_as_user_id"
    t.integer "created_by_id"
    t.string "purpose"
    t.datetime "expires_at", precision: nil, null: false
    t.integer "max_uses"
    t.integer "use_count", default: 0, null: false
    t.datetime "revoked_at", precision: nil
    t.datetime "last_used_at", precision: nil
    t.boolean "public_link", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_rd_share_links_on_expires_at"
    t.index ["template_id", "revoked_at"], name: "index_rd_share_links_on_template_and_revoked"
    t.index ["token_digest"], name: "index_rd_share_links_on_token_digest", unique: true
  end

  create_table "reporter_dashboards_template_versions", force: :cascade do |t|
    t.integer "template_id", null: false
    t.integer "author_id"
    t.text "content"
    t.string "content_digest"
    t.datetime "created_at", precision: nil, null: false
    t.index ["content_digest"], name: "index_rd_versions_on_content_digest"
    t.index ["template_id", "created_at"], name: "index_rd_versions_on_template_and_created"
  end

  create_table "reporter_dashboards_templates", force: :cascade do |t|
    t.integer "project_id"
    t.integer "author_id", null: false
    t.string "name", null: false
    t.text "description"
    t.text "content"
    t.string "source", default: "issues", null: false
    t.string "output", default: "combined", null: false
    t.integer "visibility", default: 0, null: false
    t.string "orientation", default: "portrait", null: false
    t.string "page_size", default: "A4", null: false
    t.string "margins"
    t.string "engine_hint"
    t.boolean "enabled", default: true, null: false
    t.integer "source_template_id"
    t.string "source_digest"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "failure_document", default: false, null: false
    t.index ["author_id"], name: "index_rd_templates_on_author_id"
    t.index ["project_id", "name"], name: "index_rd_templates_on_project_and_name"
    t.index ["project_id", "visibility"], name: "index_rd_templates_on_project_and_visibility"
    t.index ["source_template_id"], name: "index_rd_templates_on_source_template_id", unique: true
  end

  create_table "reporter_dashboards_templates_roles", id: false, force: :cascade do |t|
    t.integer "template_id", null: false
    t.integer "role_id", null: false
    t.index ["template_id", "role_id"], name: "index_rd_templates_roles_ids", unique: true
  end

  create_table "reporter_project_tabs", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "position"
    t.text "layout"
    t.text "settings"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["project_id", "position"], name: "index_reporter_project_tabs_on_project_id_and_position"
  end

  create_table "repositories", id: :serial, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.string "url", default: "", null: false
    t.string "login", limit: 60, default: ""
    t.string "password", default: ""
    t.string "root_url", limit: 255, default: ""
    t.string "type"
    t.string "path_encoding", limit: 64
    t.string "log_encoding", limit: 64
    t.text "extra_info"
    t.string "identifier"
    t.boolean "is_default", default: false
    t.datetime "created_on", precision: nil
    t.index ["project_id"], name: "index_repositories_on_project_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, default: "", null: false
    t.integer "position"
    t.boolean "assignable", default: true
    t.integer "builtin", default: 0, null: false
    t.text "permissions"
    t.string "issues_visibility", limit: 30, default: "default", null: false
    t.string "users_visibility", limit: 30, default: "members_of_visible_projects", null: false
    t.string "time_entries_visibility", limit: 30, default: "all", null: false
    t.boolean "all_roles_managed", default: true, null: false
    t.text "settings"
    t.integer "default_time_entry_activity_id"
  end

  create_table "roles_managed_roles", id: false, force: :cascade do |t|
    t.integer "role_id", null: false
    t.integer "managed_role_id", null: false
    t.index ["role_id", "managed_role_id"], name: "index_roles_managed_roles_on_role_id_and_managed_role_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "settings", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, default: "", null: false
    t.text "value"
    t.datetime "updated_on", precision: nil
    t.index ["name"], name: "index_settings_on_name"
  end

  create_table "subtasks", force: :cascade do |t|
    t.integer "parent"
    t.integer "child"
    t.integer "project_id"
    t.boolean "default"
    t.boolean "auto"
    t.integer "template"
    t.boolean "global"
    t.boolean "inheritance"
    t.json "custom_fields"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type"
    t.integer "color"
    t.datetime "created_at"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type"], name: "index_taggings_on_taggable_id_and_taggable_type"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.integer "color"
  end

  create_table "time_entries", id: :serial, force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "user_id", null: false
    t.integer "issue_id"
    t.float "hours", null: false
    t.string "comments", limit: 1024
    t.integer "activity_id", null: false
    t.date "spent_on", null: false
    t.integer "tyear", null: false
    t.integer "tmonth", null: false
    t.integer "tweek", null: false
    t.datetime "created_on", precision: nil, null: false
    t.datetime "updated_on", precision: nil, null: false
    t.integer "author_id"
    t.index ["activity_id"], name: "index_time_entries_on_activity_id"
    t.index ["created_on"], name: "index_time_entries_on_created_on"
    t.index ["issue_id"], name: "time_entries_issue_id"
    t.index ["project_id"], name: "time_entries_project_id"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
  end

  create_table "tokens", id: :serial, force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.string "action", limit: 30, default: "", null: false
    t.string "value", limit: 40, default: "", null: false
    t.datetime "created_on", precision: nil, null: false
    t.datetime "updated_on", precision: nil
    t.index ["user_id"], name: "index_tokens_on_user_id"
    t.index ["value"], name: "tokens_value", unique: true
  end

  create_table "trackers", id: :serial, force: :cascade do |t|
    t.string "name", limit: 30, default: "", null: false
    t.integer "position"
    t.boolean "is_in_roadmap", default: true, null: false
    t.integer "fields_bits", default: 0
    t.integer "default_status_id"
    t.string "description"
    t.boolean "private_by_default", default: false, null: false
  end

  create_table "trackers_webhooks", force: :cascade do |t|
    t.integer "tracker_id", null: false
    t.integer "webhook_id", null: false
    t.index ["tracker_id"], name: "index_trackers_webhooks_on_tracker_id"
    t.index ["webhook_id"], name: "index_trackers_webhooks_on_webhook_id"
  end

  create_table "user_preferences", id: :serial, force: :cascade do |t|
    t.integer "user_id", default: 0, null: false
    t.text "others"
    t.boolean "hide_mail", default: true
    t.string "time_zone"
    t.index ["user_id"], name: "index_user_preferences_on_user_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "login", default: "", null: false
    t.string "hashed_password", limit: 40, default: "", null: false
    t.string "firstname", limit: 30, default: "", null: false
    t.string "lastname", limit: 255, default: "", null: false
    t.boolean "admin", default: false, null: false
    t.integer "status", default: 1, null: false
    t.datetime "last_login_on", precision: nil
    t.string "language", limit: 5, default: ""
    t.integer "auth_source_id"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.string "type"
    t.string "mail_notification", default: "", null: false
    t.string "salt", limit: 64
    t.boolean "must_change_passwd", default: false, null: false
    t.datetime "passwd_changed_on", precision: nil
    t.string "twofa_scheme"
    t.string "twofa_totp_key"
    t.integer "twofa_totp_last_used_at"
    t.boolean "twofa_required", default: false
    t.index "lower((login)::text)", name: "index_users_on_lower_login"
    t.index ["auth_source_id"], name: "index_users_on_auth_source_id"
    t.index ["firstname", "lastname"], name: "index_users_on_firstname_and_lastname"
    t.index ["id", "type"], name: "index_users_on_id_and_type"
    t.index ["lastname", "firstname"], name: "index_users_on_lastname_and_firstname"
    t.index ["login"], name: "index_users_on_login"
    t.index ["type"], name: "index_users_on_type"
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.integer "project_id", default: 0, null: false
    t.string "name", default: "", null: false
    t.string "description", default: ""
    t.date "effective_date"
    t.datetime "created_on", precision: nil
    t.datetime "updated_on", precision: nil
    t.string "wiki_page_title"
    t.string "status", default: "open"
    t.string "sharing", default: "none", null: false
    t.index ["project_id"], name: "versions_project_id"
    t.index ["sharing"], name: "index_versions_on_sharing"
  end

  create_table "view_customizes", id: :serial, force: :cascade do |t|
    t.string "path_pattern", default: "", null: false
    t.text "code", null: false
    t.boolean "is_enabled", default: true, null: false
    t.boolean "is_private", default: false, null: false
    t.integer "author_id", default: 0, null: false
    t.string "insertion_position", default: "html_head", null: false
    t.string "customize_type", default: "javascript", null: false
    t.string "comments", default: "", null: false
    t.string "project_pattern", default: "", null: false
  end

  create_table "viewings", force: :cascade do |t|
    t.integer "viewer_id"
    t.integer "viewed_id"
    t.string "viewed_type"
    t.string "ip", limit: 45
    t.datetime "created_at"
    t.index ["viewed_type", "viewed_id"], name: "index_viewings_on_viewed_type_and_viewed_id"
    t.index ["viewer_id"], name: "index_viewings_on_viewer_id"
  end

  create_table "watchers", id: :serial, force: :cascade do |t|
    t.string "watchable_type", default: "", null: false
    t.integer "watchable_id", default: 0, null: false
    t.integer "user_id"
    t.index ["user_id", "watchable_type"], name: "watchers_user_id_type"
    t.index ["user_id"], name: "index_watchers_on_user_id"
    t.index ["watchable_id", "watchable_type"], name: "index_watchers_on_watchable_id_and_watchable_type"
  end

  create_table "webhooks", force: :cascade do |t|
    t.string "url", limit: 2000, null: false
    t.string "secret"
    t.text "events"
    t.integer "user_id", null: false
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_webhooks_on_active"
    t.index ["user_id"], name: "index_webhooks_on_user_id"
  end

  create_table "wiki_content_versions", id: :serial, force: :cascade do |t|
    t.integer "wiki_content_id", null: false
    t.integer "page_id", null: false
    t.integer "author_id"
    t.binary "data"
    t.string "compression", limit: 6, default: ""
    t.string "comments", limit: 1024, default: ""
    t.datetime "updated_on", precision: nil, null: false
    t.integer "version", null: false
    t.index ["updated_on"], name: "index_wiki_content_versions_on_updated_on"
    t.index ["wiki_content_id"], name: "wiki_content_versions_wcid"
  end

  create_table "wiki_contents", id: :serial, force: :cascade do |t|
    t.integer "page_id", null: false
    t.integer "author_id"
    t.text "text"
    t.string "comments", limit: 1024, default: ""
    t.datetime "updated_on", precision: nil, null: false
    t.integer "version", null: false
    t.index ["author_id"], name: "index_wiki_contents_on_author_id"
    t.index ["page_id"], name: "wiki_contents_page_id"
  end

  create_table "wiki_extensions_comments", id: :serial, force: :cascade do |t|
    t.integer "wiki_page_id"
    t.string "key_word"
    t.integer "user_id"
    t.text "comment"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "parent_id"
  end

  create_table "wiki_extensions_counts", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.integer "page_id"
    t.date "date"
    t.integer "count"
  end

  create_table "wiki_extensions_menus", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.integer "menu_no"
    t.string "page_name"
    t.string "title"
    t.boolean "enabled"
  end

  create_table "wiki_extensions_settings", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "lock_version"
    t.boolean "auto_preview_enabled", default: false, null: false
    t.boolean "tag_disabled", default: false
    t.text "tag_dropdown_options"
  end

  create_table "wiki_extensions_tag_relations", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.integer "wiki_page_id"
    t.datetime "created_at", precision: nil
    t.index ["tag_id"], name: "index_wiki_extensions_tag_relations_on_tag_id"
    t.index ["wiki_page_id"], name: "index_wiki_extensions_tag_relations_on_wiki_page_id"
  end

  create_table "wiki_extensions_tags", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.string "name"
    t.datetime "created_at", precision: nil
    t.index ["name"], name: "index_wiki_extensions_tags_on_name"
    t.index ["project_id"], name: "index_wiki_extensions_tags_on_project_id"
  end

  create_table "wiki_extensions_votes", id: :serial, force: :cascade do |t|
    t.string "keystr"
    t.string "target_class_name"
    t.integer "target_id"
    t.integer "count"
  end

  create_table "wiki_pages", id: :serial, force: :cascade do |t|
    t.integer "wiki_id", null: false
    t.string "title", limit: 255, null: false
    t.datetime "created_on", precision: nil, null: false
    t.boolean "protected", default: false, null: false
    t.integer "parent_id"
    t.index ["parent_id"], name: "index_wiki_pages_on_parent_id"
    t.index ["wiki_id", "title"], name: "wiki_pages_wiki_id_title"
    t.index ["wiki_id"], name: "index_wiki_pages_on_wiki_id"
  end

  create_table "wiki_redirects", id: :serial, force: :cascade do |t|
    t.integer "wiki_id", null: false
    t.string "title"
    t.string "redirects_to"
    t.datetime "created_on", precision: nil, null: false
    t.integer "redirects_to_wiki_id", null: false
    t.index ["wiki_id", "title"], name: "wiki_redirects_wiki_id_title"
    t.index ["wiki_id"], name: "index_wiki_redirects_on_wiki_id"
  end

  create_table "wikis", id: :serial, force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "start_page", limit: 255, null: false
    t.integer "status", default: 1, null: false
    t.index ["project_id"], name: "wikis_project_id"
  end

  create_table "workflows", id: :serial, force: :cascade do |t|
    t.integer "tracker_id", default: 0, null: false
    t.integer "old_status_id", default: 0, null: false
    t.integer "new_status_id", default: 0, null: false
    t.integer "role_id", default: 0, null: false
    t.boolean "assignee", default: false, null: false
    t.boolean "author", default: false, null: false
    t.string "type", limit: 30
    t.string "field_name", limit: 30
    t.string "rule", limit: 30
    t.integer "project_id"
    t.index ["new_status_id"], name: "index_workflows_on_new_status_id"
    t.index ["old_status_id"], name: "index_workflows_on_old_status_id"
    t.index ["project_id", "tracker_id", "role_id", "old_status_id", "field_name", "type"], name: "index_workflows_on_project_tracker_role_old_status_field_type"
    t.index ["project_id", "tracker_id", "role_id", "old_status_id", "type"], name: "index_workflows_on_project_tracker_role_old_status_type"
    t.index ["role_id", "tracker_id", "old_status_id"], name: "wkfs_role_tracker_old_status"
    t.index ["role_id"], name: "index_workflows_on_role_id"
    t.index ["tracker_id"], name: "index_workflows_on_tracker_id"
  end

  add_foreign_key "dayoffs", "leave_types"
  add_foreign_key "dayoffs", "users"
  add_foreign_key "issue_digest_deliveries", "issue_digest_runs", on_delete: :cascade
  add_foreign_key "issue_digest_deliveries", "users"
  add_foreign_key "issue_digest_rules", "projects", on_delete: :cascade
  add_foreign_key "issue_digest_rules", "users", column: "created_by_id"
  add_foreign_key "issue_digest_rules", "users", column: "updated_by_id"
  add_foreign_key "issue_digest_runs", "issue_digest_rules", on_delete: :cascade
  add_foreign_key "issue_todo_list_items", "issue_todo_lists"
  add_foreign_key "issue_todo_list_items", "issues"
  add_foreign_key "issue_todo_lists", "users", column: "created_by_id"
  add_foreign_key "issue_todo_lists", "users", column: "last_updated_by_id"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "project_workflow_scopes", "projects", on_delete: :cascade
  add_foreign_key "project_workflow_scopes", "roles", on_delete: :cascade
  add_foreign_key "project_workflow_scopes", "trackers", on_delete: :cascade
  add_foreign_key "project_workflow_scopes", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "project_workflow_scopes", "users", column: "updated_by_id", on_delete: :nullify
  add_foreign_key "project_workflow_write_locks", "roles", on_delete: :cascade
  add_foreign_key "project_workflow_write_locks", "trackers", on_delete: :cascade
  add_foreign_key "workflows", "projects", on_delete: :cascade
end
