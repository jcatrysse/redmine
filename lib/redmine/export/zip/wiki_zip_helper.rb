# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Export
    module ZIP
      module WikiZipHelper
        private

        # Returns a ZIP string of a set of wiki pages, one directory per page
        # mirroring the wiki hierarchy, with the attachments given per page id
        # written into the directory of their page
        def wiki_pages_to_zip(pages, attachments_by_page = {})
          Zip.unicode_names = true
          page_ids = pages.map(&:id)
          pages_by_parent_id = pages.group_by {|page| page.parent_id if page_ids.include?(page.parent_id)}
          directories = wiki_page_directories(pages_by_parent_id)
          buffer = Zip::OutputStream.write_buffer do |zos|
            directories.each do |page, directory|
              page_filename = "#{File.basename(directory)}.txt"
              zos.put_next_entry(zip_entry(File.join(directory, page_filename), page.updated_on))
              zos << page.content.text.to_s

              # An attachment may not take the name of the page source or of a child page directory
              child_directories = pages_by_parent_id.fetch(page.id, []).map {|child| File.basename(directories[child])}
              archived_file_names = [page_filename, *child_directories]
              attachments_by_page.fetch(page.id, []).each do |attachment|
                filename = attachment.archived_filename(archived_file_names)
                zos.put_next_entry(zip_entry(File.join(directory, filename), attachment.created_on))
                zos << File.binread(attachment.diskfile)
              end
            end
          end
          buffer.string
        ensure
          buffer&.close
        end

        # Directories mirror the wiki hierarchy so that an attachment sits next
        # to the page source referring to it
        def wiki_page_directories(pages_by_parent_id, parent_id = nil, parent_directory = '')
          archived_file_names = []
          pages_by_parent_id.fetch(parent_id, []).each_with_object({}) do |page, directories|
            name = File.basename(archived_wiki_page_filename(page, archived_file_names), '.txt')
            directory = parent_directory.blank? ? name : File.join(parent_directory, name)
            directories[page] = directory
            directories.merge!(wiki_page_directories(pages_by_parent_id, page.id, directory))
          end
        end

        def zip_entry(name, time)
          entry = Zip::Entry.new('', name)
          if time.present?
            local_time = User.current.convert_time_to_user_timezone(time)
            # DOS timestamp stores user's displayed local time
            entry.time = Zip::DOSTime.new(
              local_time.year, local_time.month, local_time.day,
              local_time.hour, local_time.min, local_time.sec
            )
            # UT extra field stores time in UTC
            entry.extra[:universaltime].mtime = local_time.utc
          end
          entry
        end

        def archived_wiki_page_filename(page, archived_file_names)
          extension = '.txt'
          # Keep this character set aligned with Attachment#sanitize_filename.
          # Unlike attachments, do not drop path-like components from wiki titles.
          sanitized_title = page.title.tr('\\', '_').gsub(/[\/?%*:|"'<>\n\r\x00]+/, '_')
          filename = "#{sanitized_title}#{extension}"
          dup_count = 0

          while archived_file_names.include?(filename)
            dup_count += 1
            filename = "#{sanitized_title}(#{dup_count})#{extension}"
          end

          archived_file_names << filename
          filename
        end
      end
    end
  end
end
