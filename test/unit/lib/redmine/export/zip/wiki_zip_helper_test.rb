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

require_relative '../../../../../test_helper'

class WikiZipHelperTest < ActiveSupport::TestCase
  include Redmine::Export::ZIP::WikiZipHelper

  def test_wiki_pages_to_zip_should_export_a_page_whose_parent_is_not_given_at_the_root
    pages = WikiPage.where(:title => ['Child_1', 'Child_1_1']).includes(:content).to_a

    assert_equal ['Child_1/Child_1.txt', 'Child_1/Child_1_1/Child_1_1.txt'],
                 zip_entry_names(wiki_pages_to_zip(pages))
  end

  private

  def zip_entry_names(zip_data)
    names = []
    Zip::InputStream.open(StringIO.new(zip_data)) do |io|
      while (entry = io.get_next_entry)
        names << entry.name
      end
    end
    names
  end
end
