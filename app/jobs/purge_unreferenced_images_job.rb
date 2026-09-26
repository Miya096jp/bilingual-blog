class PurgeUnreferencedImagesJob < ApplicationJob
  queue_as :default

  def perform
    finder = UnreferencedImageFinder.new

    if finder.unresolvable_urls.any?
      Rails.logger.warn "[PurgeUnreferencedImagesJob] blob に復元できない URL が本文にあるため削除を中止した: #{finder.unresolvable_urls.join(', ')}"
      return
    end

    purged_count = 0
    finder.candidates.find_each do |blob|
      blob.purge
      purged_count += 1
    end
    Rails.logger.info "[PurgeUnreferencedImagesJob] #{purged_count} 件の画像を削除した"
  end
end
