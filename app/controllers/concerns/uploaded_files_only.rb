# Active Storage の添付は、ファイルの代わりに blob の signed_id の文字列も受け付ける。
# 本文の画像 URL には signed_id が含まれるため、他人の blob を自分の添付にして削除できてしまう。
# 添付のパラメータは、アップロードされたファイル以外を取り除いてから渡す。
module UploadedFilesOnly
  extend ActiveSupport::Concern

  private

  def uploaded_files_only(permitted, *keys)
    keys.each do |key|
      permitted.delete(key) if permitted.key?(key) && !permitted[key].is_a?(ActionDispatch::Http::UploadedFile)
    end
    permitted
  end
end
