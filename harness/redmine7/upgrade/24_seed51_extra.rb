# Run 2 addition to the seed (verifies F6): non-default values for the GEOxyz 5.1 settings that 7.0 renamed or
# dropped, as an administrator would have set them on Administration > Settings > Repositories / General.
Setting.display_under_single_revision = '1'
Setting.display_under_associated_revisions = '1'
Setting.display_revision_branches_regex_enable = '1'
Setting.display_revision_branches_enable_regex_delimiters = "^tmp/\nrelease-[0-9]+\nfeature/a,b\n[unclosed"
Setting.search_token_limit = '10'
puts Setting.where(name: %w[display_under_single_revision display_under_associated_revisions display_revision_branches_regex_enable display_revision_branches_enable_regex_delimiters search_token_limit]).pluck(:name, :value).inspect
