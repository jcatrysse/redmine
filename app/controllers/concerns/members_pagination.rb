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

module MembersPagination
  extend ActiveSupport::Concern

  private

  def paginate_project_members(project)
    scope = project.memberships.preload(:project).sorted
    @member_count = scope.count
    @member_pages = Redmine::Pagination::Paginator.new(@member_count, per_page_option,
                                                       params[:members_page], 'members_page')
    @memberships =
      scope.offset(@member_pages.offset).limit(@member_pages.per_page).to_a
  end
end
