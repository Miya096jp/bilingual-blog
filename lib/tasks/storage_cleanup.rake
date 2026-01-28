namespace :storage do
  def get_storage_logger
    log_file = Rails.root.join("log", "storage_cleanup.log")
    logger = Logger.new(log_file, "daily", 7)

    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end

    logger
  end

  def find_target_blobs
    ActiveStorage::Blob.unattached.where("created_at < ?", 24.hours.ago)
  end

  desc "Clean up unattached blobs older than 24 hours (Logging to file)"
  task cleanup_unattached: :environment do
    logger = get_storage_logger
    logger.info "=== Starting storage cleanup task ==="

    target_blobs = find_target_blobs
    total_count = target_blobs.count

    if total_count.zero?
      logger.info "No unattached blobs found. Exiting."
      next
    end

    logger.info "Found #{total_count} unattached blobs. Processing..."

    deleted_count = 0
    failed_count = 0
    total_size = 0

    target_blobs.find_each do |blob|
      begin
        size = blob.byte_size
        key = blob.key
        filename = blob.filename.to_s

        blob.purge

        total_size += size
        deleted_count += 1

        logger.info "Deleted: #{key} (#{filename}) - #{size} bytes"

      rescue => e
        failed_count += 1
        logger.error "FAILED to delete blob #{blob&.key}: #{e.message}"
        logger.error e.backtrace.join("\n")
      end
    end

    logger.info "=== Cleanup Summary ==="
    logger.info "  Total processed: #{total_count}"
    logger.info "  Success: #{deleted_count}"
    logger.info "  Failed: #{failed_count}"
    logger.info "  Freed space: #{(total_size / 1024.0 / 1024.0).round(2)} MB"
    logger.info "======================="
  end

  desc "Show statistics about unattached blobs without deleting them"
  task stats: :environment do
    logger = get_storage_logger
    logger.info "=== Starting Statistics Check ==="

    target_blobs = find_target_blobs
    count = target_blobs.count

    if count.zero?
      logger.info "Status: Clean (No unattached blobs found)"
      logger.info "=== Statistics Check Completed ==="
      next
    end

    total_size = target_blobs.sum(:byte_size)
    oldest = target_blobs.minimum(:created_at)
    newest = target_blobs.maximum(:created_at)

    logger.info "Unattached Blob Statistics:"
    logger.info "  Count: #{count}"
    logger.info "  Total size: #{total_size} bytes (#{(total_size / 1024.0 / 1024.0).round(2)} MB)"
    logger.info "  Oldest: #{oldest}"
    logger.info "  Newest: #{newest}"

    logger.info "=== Statistics Check Completed ==="
  end
end
