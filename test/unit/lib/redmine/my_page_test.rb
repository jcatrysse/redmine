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

require_relative '../../../test_helper'

class Redmine::MyPageTest < ActiveSupport::TestCase
  def test_max_occurs_should_return_one_by_default
    assert_equal 1, Redmine::MyPage.max_occurs('news')
  end

  def test_max_occurs_should_return_an_integer_max_occurs
    Redmine::MyPage.stubs(:blocks).returns({'news' => {:label => :label_news_latest, :max_occurs => 2}})
    assert_equal 2, Redmine::MyPage.max_occurs('news')
  end

  def test_max_occurs_should_read_the_setting_named_by_max_occurs
    with_settings :my_page_max_issuequery_blocks => '7' do
      assert_equal 7, Redmine::MyPage.max_occurs('issuequery')
    end
  end

  def test_max_occurs_should_return_zero_when_the_setting_is_zero
    with_settings :my_page_max_issuequery_blocks => '0' do
      assert_equal 0, Redmine::MyPage.max_occurs('issuequery')
    end
  end

  def test_max_occurs_should_return_one_for_an_unknown_block
    assert_equal 1, Redmine::MyPage.max_occurs('issuequery__1')
    assert_equal 1, Redmine::MyPage.max_occurs('does_not_exist')
  end
end
