# Removes the settings of 5.1-stable-GEOxyz that 7.0 no longer declares, once
# 20261014120000 has copied them. Setting#value raises NoMethodError on a row
# whose name is not in config/settings.yml.
class RemoveGeoxyz51Settings < ActiveRecord::Migration[8.1]
  NAMES = %w(
    display_under_single_revision display_under_associated_revisions
    display_revision_branches_regex_enable display_revision_branches_enable_regex_delimiters
    search_token_limit
  )

  def up
    Setting.where(:name => NAMES).delete_all
  end

  def down
    # no-op
  end
end
