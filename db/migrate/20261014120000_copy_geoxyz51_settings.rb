# Carries the settings of 5.1-stable-GEOxyz over to the names 7.0-stable-GEOxyz
# uses for the same features. A setting already stored under its new name is
# left alone.
class CopyGeoxyz51Settings < ActiveRecord::Migration[8.1]
  def up
    copy_setting 'display_revision_branches', old_setting('display_under_single_revision')
    copy_setting 'display_associated_revision_branches', old_setting('display_under_associated_revisions')
    copy_excluded_branches

    limit = old_setting('search_token_limit')
    if limit.present? && limit.to_i != 5
      say "search_token_limit was #{limit}: the global search now uses the first 5 tokens " \
          "and text filters use all of them"
    end
  end

  def down
    # no-op
  end

  private

  def old_setting(name)
    Setting.where(:name => name).pick(:value)
  end

  def copy_setting(name, value)
    return if value.nil? || Setting.where(:name => name).exists?

    Setting.create!(:name => name, :value => value)
  end

  # 5.1 matched each line as an unanchored, case-sensitive regular expression,
  # and only when display_revision_branches_regex_enable was on. 7.0 takes a
  # comma-separated list and anchors each pattern, case-insensitively.
  def copy_excluded_branches
    return unless old_setting('display_revision_branches_regex_enable') == '1'
    return if Setting.where(:name => %w(revision_branches_excluded revision_branches_enable_regex)).exists?

    patterns = old_setting('display_revision_branches_enable_regex_delimiters').to_s.split(/[\r\n]+/).reject(&:blank?)
    patterns = patterns.select do |pattern|
      Regexp.new(pattern)
      next true unless pattern.include?(',')

      say "display_revision_branches_enable_regex_delimiters: #{pattern} contains a comma and is not copied"
      false
    rescue RegexpError
      say "display_revision_branches_enable_regex_delimiters: #{pattern} is not a valid regular expression and is not copied"
      false
    end
    return if patterns.empty?

    copy_setting 'revision_branches_excluded', patterns.map {|pattern| ".*(?-i:#{pattern}).*"}.join(',')
    copy_setting 'revision_branches_enable_regex', '1'
  end
end
