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
  # The session store's own serializer, with one difference: a row it cannot
  # parse is an empty session rather than an exception.
  #
  # The store defaults to Marshal, which means every request runs Marshal.load
  # over a database column that carries no signature. JSON keeps that out of
  # the request path, but it also cannot read a row an older Marshal-based
  # deploy wrote, and those rows are still there after a restart. Raising on
  # them would give every logged-in user a 500 until their row expires; an
  # empty session logs them out once, which is what the cookie store does with
  # a cookie it cannot verify.
  class SessionDataSerializer < ActiveRecord::SessionStore::ClassMethods::JsonSerializer
    def self.load(value)
      super
    rescue JSON::ParserError
      {}
    end
  end
end
