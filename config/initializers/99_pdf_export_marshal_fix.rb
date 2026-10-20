# frozen_string_literal: true

# Hotfix for Redmine 5.1: exporting an issue with a table to PDF fails with
# "can't dump hash with default proc" (RBPDF error: writeHTMLCell Error).
# Same change as 7.0-stable-GEOxyz f592381 (lib/redmine/export/pdf.rb), so it can be removed
# after the upgrade to 7.0.
#
# RBPDF starts a transaction for a table header and deep-copies the PDF object with Marshal.
# The copy included the attachments given to RDMwriteFormattedCell and, through them, the
# container and its loaded users, whose cached roles are hashes with a default proc.
Rails.application.config.to_prepare do
  pdf_class = Redmine::Export::PDF::ITCPDF
  next if pdf_class.const_defined?(:SharedAttachmentsInTransaction, false)

  pdf_class.const_set(:SharedAttachmentsInTransaction, Module.new do
    # The copy made by startTransaction shares the attachments instead of marshaling them
    def objclone(object)
      attachments = object.instance_variable_get(:@attachments)
      object.instance_variable_set(:@attachments, nil)
      copy = super
      copy.instance_variable_set(:@attachments, attachments)
      copy
    ensure
      object.instance_variable_set(:@attachments, attachments)
    end
  end)
  pdf_class.prepend(pdf_class::SharedAttachmentsInTransaction)
end
