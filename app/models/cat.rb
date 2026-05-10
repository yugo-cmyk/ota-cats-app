class Cat < ApplicationRecord
  has_one_attached :image

  # 保存する前に、写真から位置情報を抜き出す処理（HEIC対応版）
  before_save :process_image_and_gps

  private

  def process_image_and_gps
    # 手動ですでに緯度経度が入力されている場合は、自動取得より手動を優先する
    return if latitude.present? && longitude.present?

    # 画像が添付されていない、または変更がない場合は終了
    return unless image.attached?
    return unless attachment_changes["image"]

    # ファイルパスの取得
    blob = attachment_changes["image"].attachable
    file_path = blob.try(:path) || blob.try(:tempfile)&.path
    return unless file_path && File.exist?(file_path)

    # HEIC形式の判定
    is_heic = File.extname(file_path).downcase =~ /\.heic|\.heif/
    working_path = file_path
    temp_jpg = nil

    # HEICをJPGに変換（iPhone対策）
    if is_heic
      temp_jpg = "/tmp/heic_tmp_#{SecureRandom.hex}.jpg"
      # Render環境に heif-convert がインストールされている前提
      system("heif-convert #{file_path} #{temp_jpg}")
      working_path = temp_jpg if File.exist?(temp_jpg)
    end

    # identifyコマンドを使用してEXIF情報を抽出
    lat_raw = `identify -format '%[EXIF:GPSLatitude]' "#{working_path}"`.strip
    lng_raw = `identify -format '%[EXIF:GPSLongitude]' "#{working_path}"`.strip
    lat_ref = `identify -format '%[EXIF:GPSLatitudeRef]' "#{working_path}"`.strip
    lng_ref = `identify -format '%[EXIF:GPSLongitudeRef]' "#{working_path}"`.strip

    # 座標が存在すれば変換して保存
    if lat_raw.present? && lng_raw.present?
      self.latitude = parse_exif_coordinate(lat_raw, lat_ref)
      self.longitude = parse_exif_coordinate(lng_raw, lng_ref)
    end

    # 一時ファイルの削除
    File.delete(temp_jpg) if is_heic && temp_jpg && File.exist?(temp_jpg)
  rescue => e
    Rails.logger.error "GPS抽出プロセスでエラーが発生しました: #{e.message}"
  end

  # EXIFの度分秒形式を数値に変換するメソッド
  def parse_exif_coordinate(coord_str, ref)
    parts = coord_str.to_s.split(',').map { |p| p.strip.split('/') }
    decimal_parts = parts.map { |p| p.size == 2 ? p[0].to_f / p[1].to_f : p[0].to_f }
    return nil if decimal_parts.size < 3
    
    res = decimal_parts[0] + (decimal_parts[1] / 60.0) + (decimal_parts[2] / 3600.0)
    (ref == "S" || ref == "W") ? -res : res
  end
end