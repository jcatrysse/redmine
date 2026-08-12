# frozen_string_literal: true

require_relative '../../../test_helper'
require 'net/imap'

class Redmine::IMAPTest < ActiveSupport::TestCase
  def test_check_uses_login_by_default
    imap = mock('imap')
    Net::IMAP.expects(:new).with('127.0.0.1', port: '143', ssl: false).returns(imap)
    imap.expects(:starttls).never
    imap.expects(:login).with('user', 'secret')
    imap.expects(:select).with('INBOX')
    imap.expects(:uid_search).returns([])
    imap.expects(:expunge)
    imap.expects(:logout)
    imap.expects(:disconnect)

    Redmine::IMAP.check(:username => 'user', :password => 'secret')
  end

  def test_check_uses_authenticate_when_auth_type_is_set
    imap = mock('imap')
    Net::IMAP.expects(:new).with(
      'imap.example.com',
      port: '993',
      ssl: {verify_mode: OpenSSL::SSL::VERIFY_PEER}
    ).returns(imap)
    imap.expects(:starttls)
    imap.expects(:authenticate).with('XOAUTH2', 'user', 'token')
    imap.expects(:select).with('INBOX')
    imap.expects(:uid_search).returns([])
    imap.expects(:expunge)
    imap.expects(:logout)
    imap.expects(:disconnect)

    Redmine::IMAP.check(
      :host => 'imap.example.com',
      :port => '993',
      :ssl => true,
      :starttls => true,
      :username => 'user',
      :password => 'token',
      :auth_type => 'XOAUTH2'
    )
  end
end
